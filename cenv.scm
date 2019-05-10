#!/usr/bin/env csi -script

(import (chicken file)
        (chicken file posix)
        (chicken irregex)
        (chicken pathname)
        (chicken platform)
        (chicken process)
        (chicken process-context))

;; kinda silly
(define (parse-args #!optional (args (command-line-arguments)))
  (when (null? args)
    (usage))
  (let ((verb (car args))
        (rest (cdr args)))
    `((command . ,(executable-pathname))
      (verb . ,(string->symbol verb))
      (args . ,rest))))

(define (usage)
  (print "usage: " (program-name) " init <dir>")
  (exit 1))

(define (dispatch)
  (let ((args (parse-args)))
    (let ((verb (alist-ref 'verb args)))
      (case verb
        ((init)
         (let ((args (alist-ref 'args args)))
           (when (null? args)
             (usage))
           (cenv-init-repository (car args))))
        (else
         (usage))))))

(define (template str alist)
  (irregex-replace/all "{{([A-Za-z0-9_-]+)}}"
                       str
                       (lambda (m)
                         (let ((key (string->symbol (irregex-match-substring m 1))))
                           (or (alist-ref key alist)
                               (error 'template "missing value for key" key))))))

;; realpath is available as C_realpath but only if we compile.
(define (realpath x)
  (normalize-pathname
   (if (absolute-pathname? x)
       x
       (make-pathname (current-directory) x))))
(define (last x)
  (if (pair? (cdr x))
      (last (cdr x))
      (car x)))

;; We precompute our env dir, the chicken prefix, and the chicken system repo; so we
;; cannot relocate, but it makes things simpler.
;; We may want to ignore any CHICKEN_REPOSITORY_PATH set in the calling environment;
;; we currently honor it, which is of debatable utility.
(define center-data #<<EOF
#!/bin/bash

export CHICKEN_PREFIX="{{prefix}}"
export CHICKEN_ENV="{{env}}"
export CHICKEN_INSTALL_PREFIX=$CHICKEN_ENV
export CHICKEN_INSTALL_REPOSITORY=$CHICKEN_INSTALL_PREFIX/lib
export PATH=$CHICKEN_INSTALL_PREFIX/bin:$CHICKEN_PREFIX/bin:$PATH
export CHICKEN_REPOSITORY_PATH="$CHICKEN_INSTALL_REPOSITORY:{{sys-repo}}"

# chicken-doc repo defaults to being in system shared dir when unset;
# preserve this behavior for local envs.
if [ -z "${CHICKEN_DOC_REPOSITORY+x}" ]; then
   export CHICKEN_DOC_REPOSITORY=$CHICKEN_INSTALL_PREFIX/share/chicken-doc
fi

EOF
)

(define cexec-data #<<EOF
#!/bin/sh

. {{env}}/bin/center
exec "$@"

EOF
)

(define chicken-prefix
  ;; Note: If we compile, we can obtain prefix via foreign-variable, but
  ;;       it is not exposed by default. Otherwise, we just assume chicken-home
  ;;       is the default and reverse engineer the prefix.
  (let ((m (irregex-match "(.+)/share/chicken" (chicken-home))))
    (if m
        (irregex-match-substring m 1)
        (error "Unable to determine chicken prefix from " (chicken-home)))))

(define (create-cexec dirname)
  (let ((cexec (string-append dirname "/bin/cexec")))
    (with-output-to-file cexec
      (lambda () (print (template cexec-data
                             `((env . ,(realpath dirname)))))))
    (set! (file-permissions cexec) #o0755)))    ; ignores umask, probably

(define (create-center dirname)
  (let ((center (string-append dirname "/bin/center")))
    (with-output-to-file center
        (lambda () (print (template center-data
                               `((prefix . ,chicken-prefix)
                                 (env . ,(realpath dirname))
                                 (sys-repo . ,(last (repository-path))))))))
    (set! (file-permissions center) #o0644)))

(define (test-cenv dirname)
;; This is available in CHICKEN_REPOSITORY_PATH after entering environment,
;; but double-check that it works by running csi via cexec.
  (print "New repository path:")
  (system* (string-append (string-append dirname "/bin/cexec ")
                          "csi -R chicken.platform -p '(repository-path)'")))

(define (cenv-init-repository dirname)
  (print "Using CHICKEN " (chicken-version) " in " chicken-prefix)
  (print "Initializing repository in " dirname)
  (for-each (cut create-directory <> #t)
            (map (cut string-append dirname <>)
                 '("/bin" "/lib" "/share")))
  (create-center dirname)
  (create-cexec dirname)
  (test-cenv dirname))

(dispatch)
