# SCCM-Install-Scripts
My install scripts for installing large or fussy programs through SCCM

## About 
For applications that are particularly large and/or are not able to be installed via MSI packages, the scripts in this repo have been created to more easily and effectively deploy them via SCCM. At this  time, all of the scripts in this repo were designed to be distributed and run with WIM archives containing the install files in the same directory. 

### Backstory
My organization was tasked with transitioning to SCCM for application installation, and we were met with some issues regarding some applications, particularly those large in size or difficult (legacy) to install. With some searching, I discovered that it's relatively easy to distribute, mount, and install from Windows images (WIMs). This would stop us from needing to either copy a large amount of smaller files culminating in 5-10GB or from copying a compressed archive that needed to be extracted before it could be reliably installed from. In addition to the other benefits, this also allowed us to deploy to hosts not directly on the company LAN or VPN.

## Application List
- TeamCenter 12
  - A long and complicated install process, uses multiple JARs and batch files straight from the manufacturer
- NX v1953
  - Installs quietly and easily via MSI, but is a very large install with a lot of small files

## To-Do
- [ ] Create template install .ps1's
- [ ] Consolidate common functions into a separate script that can be imported into each install script
- [ ] Create a script to simplify the creation of each install script, as well as package the WIM
- [ ] Update readme/wiki with instructions on how to use
