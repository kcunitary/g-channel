(define-module (soEvil services proxy)
  #:use-module (ice-9 match)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (gnu packages admin)
  #:use-module (gnu services)
  #:use-module (gnu services configuration)
  #:use-module (gnu services shepherd)
  #:use-module (gnu system shadow)
  #:use-module (soEvil packages proxy)
  #:export (v2ray-configuration v2ray-service-type))

(define %default-v2ray-conf
  (plain-file "config.json"
              "{\n  \"log\": {\n    \"loglevel\": \"warning\"\n  },\n  \"inbounds\": [{\n    \"port\": 1080,\n    \"listen\": \"127.0.0.1\",\n    \"protocol\": \"socks\",\n    \"settings\": {\n      \"auth\": \"noauth\",\n      \"udp\": false,\n      \"ip\": \"127.0.0.1\"\n    }\n  }],\n  \"outbounds\": [{\n    \"protocol\": \"freedom\",\n    \"settings\": {},\n    \"tag\": \"direct\"\n  }],\n  \"policy\": {\n    \"levels\": {\n      \"0\": {\"uplinkOnly\": 0}\n    }\n  }\n}\n"))
(define %v2ray-accounts
  (list (user-group
          (name "v2ray")
          (system? #t))
        (user-account
          (name "v2ray")
          (group "v2ray")
          (system? #t)
          (comment "v2ray user")
          (home-directory "/var/empty")
          (shell (file-append shadow "/sbin/nologin")))))

(define-configuration/no-serialization v2ray-configuration
                                       (v2ray (package
                                                v2ray-bin)
                                        "The v2ray package to use, we need @command{v2ray}.")
                                       (config-file (file-like
                                                     %default-v2ray-conf)
                                                    "configuration files."))

(define v2ray-shepherd-service
  (match-lambda
    (($ <v2ray-configuration> v2ray-bin config-file)
     (list (shepherd-service (documentation "Run v2ray.")
                             (provision '(v2ray))
                             (requirement '(loopback))
                             (start #~(make-forkexec-constructor '(#$(file-append
                                                                      v2ray-bin
                                                                      "/bin/v2ray")
                                                                   "run" "-c"
                                                                   #$config-file)
                                                                 #:user
                                                                 "v2ray"
                                                                 #:group
                                                                 "v2ray"))
                             (stop #~(make-kill-destructor)))))))

(define v2ray-service-type
  (service-type (name 'v2ray)
                (extensions (list (service-extension
                                   shepherd-root-service-type
                                   v2ray-shepherd-service)
                                  (service-extension account-service-type
                                                     (const %v2ray-accounts))))
                (default-value (v2ray-configuration))
                (description "Run v2ray daemon.")))
