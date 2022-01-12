;; Minimal UI setup
(setq inhibit-startup-message t) 
(scroll-bar-mode -1)
(tool-bar-mode -1)
(set-fringe-mode 10)
(menu-bar-mode -1)
(setq visible-bell nil)

;;(load-theme 'doom-palenight)

(global-set-key (kbd "<escape>") 'keyboard-escape-quit)

(require 'package)
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("melpa-stable" . "https://stable.melpa.org/packages/")
                         ("org" . "https://orgmode.org/elpa/")
                         ("elpa" . "https://elpa.gnu.org/packages/")))

(package-refresh-contents) ; Failed to install evil: https://melpa.org/packages/goto-chg-20210508.1632.el: Not found
(package-initialize)
;;(unless package-archive-contents
;;  (package-refresh-contents))

(column-number-mode)
(global-display-line-numbers-mode t)
;; Disable line numbers for some modes
(dolist (mode '(org-mode-hook
	        term-mode-hook
	        eshell-mode-hook
		shell-mode-hook))
  (add-hook mode (lambda () (display-line-numbers-mode 0))))


(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t) ; install package if not found in use-package environment

(use-package ivy
  :diminish
  :demand
  :bind (("C-s" . swiper)
	 :map ivy-minibuffer-map
	 ("TAB" . ivy-alt-done)
	 ("C-l" . ivy-alt-done)
	 ("C-j" . ivy-next-line)
	 ("C-k" . ivy-previous-line)
	 :map ivy-switch-buffer-map
	 ("C-k" . ivy-previous-line)
	 ("C-l" . ivy-done)
	 ("C-d" . ivy-switch-buffer-kill)
	 :map ivy-reverse-i-search-map
	 ("C-k" . ivy-previous-line)
	 ("C-d" . ivy-reverse-i-search-kill))
  :config (ivy-mode 1))

(use-package ivy-rich
  :init
  (ivy-rich-mode 1))

(use-package counsel
  :bind (("M-x" . counsel-M-x)
	 ("C-x b" . counsel-ibuffer)
	 ("C-x C-f" . counsel-find-file)
	 :map minibuffer-local-map
	 ("C-r" . 'counsel-minibuffer-history)))

(use-package which-key
  :init (which-key-mode)
  :diminish which-key-mode
  :config (setq which-key-idle-delay 0.3))

(use-package doom-modeline
  :ensure t
  :init (doom-modeline-mode 1))

;;(use-package doom-themes)

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package modus-themes
  :init
  ;; Add all your customizations prior to loading the themes
  (setq modus-themes-italic-constructs t
        modus-themes-bold-constructs nil
        modus-themes-region '(bg-only no-extend))

  ;; Load the theme files before enabling a theme (else you get an error).
  (modus-themes-load-themes)
  :config
  ;; Load the theme of your choice:
  (modus-themes-load-vivendi)
  :bind ("<f5>" . modus-themes-toggle))

(use-package helpful
  :custom
  (counsel-describe-function-function #'helpful-callable)
  (counsel-describe-variable-function #'helpful-variable)
  :bind
  ([remap describe-function] . helpful-function)
  ([remap describe-symbol] . helpful-symbol)
  ([remap describe-variable] . helpful-variable)
  ([remap describe-command] . helpful-command)
  ([remap describe-key] . helpful-key))


(use-package undo-tree
  :init
  (global-undo-tree-mode 1)) ; override emacs' undo with undo-tree package all buffers

(use-package evil
  :init      ;; tweak evil's configuration before loading it
  (setq evil-want-integration t) ;; This is optional since it's already set to t by default.
  (setq evil-want-keybinding nil)
  (setq evil-vsplit-window-right t)
  (setq evil-split-window-below t)
  (setq evil-respect-visual-line-mode t)
  (setq evil-undo-function 'undo-tree-undo)
  (setq evil-redo-function 'undo-tree-redo)
  (evil-mode))

;;(use-package evil-collection
;;  :after evil
;;  :config
;;  (setq evil-collection-mode-list '(dashboard dired ibuffer))
;;  (evil-collection-init))
;;(use-package evil-tutor)

