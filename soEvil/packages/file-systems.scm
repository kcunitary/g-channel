(define-module (soEvil packages file-systems)
  #:use-module (guix packages)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix download)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages linux)
  #:use-module (guix utils)
  #:use-module (guix git-download)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages rsync)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages autotools)
  #:use-module (guix gexp)
  #:use-module (guix build utils))

(define-public mergerfs
  (package
    (name "mergerfs")
    (version "2.35.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/trapexit/mergerfs/"
                           "releases/download/" version "/"
                           "mergerfs-" version ".tar.gz"))
       (sha256
        (base32 "1p7x91zkx6hy1p668p49dry4wl5f8d8q5l3mglc980rcl3qfck75"))))
    (build-system gnu-build-system)
    (arguments
     `(#:make-flags
       (list (string-append "CC=" ,(cc-for-target))
             (string-append "CXX=" ,(cxx-for-target))
             (string-append "PREFIX=" (assoc-ref %outputs "out")))
       #:tests? #f                     ; all require a kernel with FUSE loaded
       #:phases
       (modify-phases %standard-phases
         (delete 'configure)            ; no configure script
         (add-after 'unpack 'set-file-names
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (substitute* "libfuse/Makefile"
               (("/sbin") "$(EXEC_PREFIX)/sbin")
               (("chown") "true")  ; disallowed in the build environment
               (("strip") "true")) ; breaks cross-compilation
             ;; These were copied from the fuse package.
             (substitute* '("libfuse/lib/mount_util.c"
                            "libfuse/util/mount_util.c")
               (("/bin/(u?)mount" _ maybe-u)
                (search-input-file inputs
                                   (string-append "bin/" maybe-u
                                                  "mount"))))
             (substitute* '("libfuse/util/mount.mergerfs.c")
               (("/bin/sh" command)
                (string-append (assoc-ref inputs "bash-minimal") command))
               ;; mount.mergerfs tries to execute `mergerfs`, which cannot be found
               ;; without an absolute path. Hard-coding the path is fine, since we don’t
               ;; link mount.mergerfs to mount.fuse anyway.
               (("add_arg\\(&command, type\\);")
                (string-append "add_arg(&command, \"" (assoc-ref outputs "out")
                               "/bin/mergerfs\");"))))))))
    ;; Mergerfs bundles a heavily modified copy of fuse.
    (inputs
     (list bash-minimal util-linux))
    (home-page "https://github.com/trapexit/mergerfs")
    (synopsis "Featureful union file system")
    (description "mergerfs is a union file system geared towards simplifying
storage and management of files across numerous commodity storage devices.  It
is similar to mhddfs, unionfs, and aufs.")
    (license (list
              license:isc                   ; mergerfs
              license:gpl2 license:lgpl2.0  ; Imported libfuse code.
              ))))

(define-public mergerfs-tools
  (let ((commit "ff4ef0355f699eb11f0d75471d3df44c303830a3")
        (revision "0"))
    (package
      (name "mergerfs-tools")
      ;; No released version exists.
      (version (git-version "0.0.0" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/trapexit/mergerfs-tools")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "12nf1b6fsarb9iixadxpz5j2xlp3jszwcax4pdba1x86q0j8xp6r"))))
      (build-system copy-build-system)
      (inputs
       (list python python-xattr rsync))
      (arguments
       '(#:install-plan
         '(("src/" "bin/"))
         #:phases
         (modify-phases %standard-phases
           (add-after 'unpack 'patch-paths
             (lambda* (#:key inputs #:allow-other-keys)
               (substitute* (find-files "src" "^mergerfs\\.")
                 (("'rsync'")
                  (string-append "'" (assoc-ref inputs "rsync") "/bin/rsync'"))
                 (("'rm'")
                  (string-append "'" (assoc-ref inputs "coreutils") "/bin/rm'")))
               (substitute* "src/mergerfs.mktrash"
                 (("xattr")
                  (search-input-file inputs "/bin/xattr"))
                 (("mkdir")
                  (search-input-file inputs "/bin/mkdir"))))))))
      (synopsis "Tools to help manage data in a mergerfs pool")
      (description "mergerfs-tools is a suite of programs that can audit
permissions and ownership of files and directories on a mergerfs volume,
duplicates files and directories across branches in its pool, find and remove
duplicate files, balance pool drives, consolidate files in a single mergerfs
directory onto a single drive and create FreeDesktop.org Trash specification
compatible directories.")
      (home-page "https://github.com/trapexit/mergerfs-tools")
      (license license:isc))))

(define-public snapraid
  (package
    (name "snapraid")
    (version "12.2")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/amadvance/snapraid")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0xgvyhyyl2v6azxwzqbpgyln4r2dw34xa8z09116vpkgdgivh36z"))))
    (build-system gnu-build-system)
    (arguments
     (list #:configure-flags
           ;; XXX --enable-valgrind fails with ‘A must-be-redirected function
           ;; whose name matches the pattern: strlen in an object with soname
           ;; matching: ld-linux-x86-64.so.2 was not found […]’; used to work.
           #~(list "--with-blkid")
           #:phases
           #~(modify-phases %standard-phases
               (add-before 'bootstrap 'set-version
                 (lambda _
                   (setenv "VERSION" #$version)
                   (patch-shebang "autover.sh"))))))
    (native-inputs
     (list automake autoconf))
    (inputs
     (list `(,util-linux "lib"))) ; libblkid
    (home-page "https://www.snapraid.it/")
    (synopsis "Efficient backups using parity snapshots across disk arrays")
    (description
     "SnapRAID backs up files stored across multiple storage devices, such as
disk arrays, in an efficient way reminiscent of its namesake @acronym{RAID,
Redundant Array of Independent Disks} level 4.

Instead of creating a complete copy of the data like classic backups do, it
saves space by calculating one or more sets of parity information that's a
fraction of the size.  Each parity set is stored on an additional device the
size of the largest single storage volume, and protects against the loss of any
one device, up to a total of six.  If more devices fail than there are parity
sets, (only) the files they contained are lost, not the entire array.  Data
corruption by unreliable devices can also be detected and repaired.

SnapRAID is distinct from actual RAID in that it operates on files and creates
distinct snapshots only when run.  It mainly targets large collections of big
files that rarely change, like home media centers.  One disadvantage is that
@emph{all} data not in the latest snapshot may be lost if one device fails.  An
advantage is that accidentally deleted files can be recovered, which is not the
case with RAID.

It's also more flexible than true RAID: devices can have different sizes and
more can be added without disturbing others.  Devices that are not in use can
remain fully idle, saving power and producing less noise.")
    (license license:gpl3+)))
