(define-module (soEvil packages proxy)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system copy)
  #:use-module (guix licenses)
  #:use-module (guix build utils))

(define-public v2ray-bin
  (package
    (name "v2ray-bin")
    (version "5.3.0")
    (source (origin
              (method url-fetch/zipbomb)
              (uri (string-append
                    "https://github.com/v2fly/v2ray-core/releases/download/v"
                    version "/v2ray-linux-64.zip"))
              (file-name (string-append "v2ray-bin-" version ".zip"))
              (sha256
               (base32
                "171wglzyrijxxqhqfjyjf0hlkwp4vgj923p54gccdsi8f5sqkw3c"))))
    (build-system copy-build-system)
    (arguments
     `(#:install-plan '(("v2ray" "bin/")
                        ("." "share/v2ray-geodata"
                         #:include ("dat")))
       #:phases (modify-phases %standard-phases
                  (add-after 'install 'post-process-binary
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bin (string-append out "/bin"))
                             (assets-dir (string-append out
                                          "/share/v2ray-geodata")))
                        (for-each (lambda (file)
                                    (remove-store-references file)
                                    (wrap-program file
                                                  `("V2RAY_LOCATION_ASSET" =
                                                    (,assets-dir))))
                                  (find-files bin)) #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/v2fly/v2ray-core")
    (synopsis "A platform for building proxies to bypass network restrictions")
    (description "Binary version of V2Ray")
    (license (@ (guix licenses) expat))))
