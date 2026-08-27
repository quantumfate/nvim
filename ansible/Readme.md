# Ansible

Provisions this Neovim config on an arch based system: installs runtime packages,
symlinks the config into `~/.config/nvim/`. 

## Run locally

```sh
ansible-galaxy collection install -r requirements.yml   
ansible-playbook playbook.yml --ask-become-pass
```

## Import from a controller

(git submodule or vendored), put `ansible/roles` on your `roles_path`, then:

```yaml
- hosts: workstation
  roles:
    - role: quickshell
      vars:
        quickshell_config_name: quantumfate
        quickshell_repo_path: /path/to/checkout
        quickshell_install_extra_packages: true # Dofus swap tooling
```

