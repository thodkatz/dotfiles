;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
(setq user-full-name "Theodoros Katzalis"
      user-mail-address "thodkatz@gmail.com")

;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
;; (setq doom-font (font-spec :family "monospace" :size 12 :weight 'semi-light)
;;       doom-variable-pitch-font (font-spec :family "sans" :size 13))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
;;(setq doom-theme 'my-doom-gruvbox)
(setq doom-theme 'doom-zenburn)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

(after! org
  ;; Make bullets in org mode fancier
  (require 'org-bullets)
  (add-hook 'org-mode-hook (lambda () (org-bullets-mode 1)))
  (add-hook 'org-mode-hook 'turn-on-flyspell) ;; start flyspell each time org is loaded, [[https://tecosaur.github.io/emacs-config/config.html][source]]
  (setq org-startup-with-inline-images t)
  (setq org-image-actual-width nil)
  (require 'org-inlinetask))

(with-eval-after-load "ispell"
  (setq ispell-program-name "hunspell")
  (setq ispell-dictionary "english")
  ;; ispell-set-spellchecker-params has to be called
  ;; before ispell-hunspell-add-multi-dic will work

  ;; you could set `ispell-dictionary` instead but `ispell-local-dictionary' has higher priority
  ;;(ispell-set-spellchecker-params)
  ;;(setq ispell-local-dictionary-alist '(("en_US" "[[:alpha:]]" "[^[:alpha:]]" "[']" nil ("-d" "en_US") nil utf-8)))

  ;; This determines the style of line numbers in effect. If set to `nil', line
  ;; numbers are disabled. For relative line numbers, set this to `relative'.
  (setq display-line-numbers-type t))

;;(setq select-enable-clipboard t) ;; make system copy-paste work with emac copy-paste

(use-package! org-roam
  :init
  (setq org-roam-db-update-on-save nil) ;; it takes too much time when saving file to update the db
  (setq org-roam-completion-everywhere t)
  (setq org-roam-v2-ack t)
  (map! :leader
        :prefix "n"
        :desc "org-roam" "l" #'org-roam-buffer-toggle
        :desc "org-roam-node-insert" "i" #'org-roam-node-insert
        :desc "org-roam-node-find" "f" #'org-roam-node-find
        :desc "org-roam-ref-find" "r" #'org-roam-ref-find
        :desc "org-roam-show-graph" "g" #'org-roam-show-graph
        :desc "org-roam-capture" "c" #'org-roam-capture)
  (setq org-roam-directory (file-truename "~/org/slipbox/slipbox_new")
        org-roam-db-gc-threshold most-positive-fixnum
        org-id-link-to-org-use-id t)
  :config
  (org-roam-setup)
  (set-popup-rules!
    `((,(regexp-quote org-roam-buffer) ; persistent org-roam buffer
       :side right :width .33 :height .5 :ttl nil :modeline nil :quit nil :slot 1)
      ("^\\*org-roam: " ; node dedicated org-roam buffer
       :side right :width .33 :height .5 :ttl nil :modeline nil :quit nil :slot 2)))

  (add-hook 'org-roam-mode-hook #'turn-on-visual-line-mode)
  (set-company-backend! 'org-mode '(company-capf))
  (require 'org-roam-protocol)
  (setq org-roam-capture-templates '(("d" "default" plain "%?"
                                      :target (file+head "${slug}.org"
                                                         "#+title: ${title}\n")
                                      :unnarrowed t)
                                     ("l" "literature" plain "%?"
                                      :target (file+head "literature/${slug}.org"
                                                         "#+title: L: ${title}\n- author :: \n- tags :: \n- source :: \n- summary :: \n")
                                      :unnarrowed t)
                                     ("p" "permanent" plain "%?"
                                      :target (file+head "permanent/${slug}.org"
                                                         "#+title: P: ${title}\n- tags :: \n- Related notes and sources :: \n- summary :: \n")
                                      :unnarrowed t)
                                     ("r" "project" plain "%?"
                                      :target (file+head "projects/${slug}.org"
                                                         "#+title: PR: ${title}\n- tags :: \n- Related notes and sources :: \n- summary :: \n")
                                      :unnarrowed t)
                                     ("t" "tag" plain "%?"
                                      :target (file+head "tags/${slug}.org"
                                                         "#+title: #${title}\n")
                                      :unnarrowed t))))

(use-package! org-roam-dailies
  :init
  (map! :leader
        :prefix "n"
        :desc "org-roam-dailies-capture-today" "j" #'org-roam-dailies-capture-today)
  :config
  (setq org-roam-dailies-directory "daily/")
  (setq org-roam-dailies-capture-templates
        '(("d" "default" entry
           "* %?"
           :if-new (file+head "%<%Y-%m-%d>.org"
                              "#+title: %<%Y-%m-%d>\n")))))


;;(require 'company-org-roam)
(use-package company-org-roam
  :when (featurep! :completion company)
  :after org-roam
  :config
  (set-company-backend! 'orgmode '(company-org-roam company-yasnippet company-dabbrev)))

(use-package org-journal
     :custom
     (org-journal-dir "~/org/slipbox/journal")
     (org-journal-date-prefix "#+TITLE:")
     (org-journal-file-format "%Y-%m-%d.org")
     (org-journal-date-format "%A, %d %B %Y"))


(use-package deft
  :after org
  :custom
  (deft-recursive t)
  (deft-use-filename-as-title t)
  ;;(deft-use-filter-string-for-filename t)
  ;;(deft-org-mode-title-prefix t)
  ;;(deft-strip-summary-regexp ":PROPERTIES:\n\\(.+\n\\)+:END:\n")
  (deft-strip-summary-regexp ":PROPERTIES:\n\\(.+\n\\)+:END:\n")
  (deft-default-extension "org")
  (deft-directory "~/org/slipbox")
)

(use-package org-super-agenda
  :after org-agenda
  :init
  (setq org-super-agenda-groups '((:name "Today"
                                  :time-grid t
                                  :scheduled today)
                                  (:name "Due today"
                                  :deadline today)
                                  (:name "Important"
                                  :priority "A")
                                  (:name "Overdue"
                                  :deadline past)
                                  (:name "Due soon"
                                  :deadline future)
                                  (:name "Big Outcomes"
                                   :tag "bo")))
  :config
  (org-super-agenda-mode))

(setq org-agenda-files (list "~/org/slipbox/"))

(use-package! ranger
  :config
  (setq ranger-override-dired 'ranger)
  (setq ranger-show-hidden t)
  (setq ranger-preview-file t))

(use-package! org-download
  :after org
  :custom
  (org-download-method 'directory)
  (org-download-image-dir "~/org/slipbox/slipbox_new/images")
  ;;(org-download-heading-lvl nil)
  ;;(org-download-timestamp "%Y%m%d-%H%M%S_")
  (org-image-actual-width 600)
  (org-download-screenshot-method "/usr/bin/scrot -s %s")
  :bind
  ("C-M-y" . org-download-screenshot)
  :config
  (require 'org-download))
