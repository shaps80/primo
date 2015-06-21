#!/bin/bash
#
# Sets up and configure your mac with initial binaries and applications
#
# To install, use the following command: TODO: replace url
# bash < <(curl -s https://raw.github.com/thoughtbot/laptop/master/mac)
#
# All configurations should be changed ONLY at the top of this file

gem_apps=(
  colorize
  bundler
  jekyll
)

brew_apps=(
  emacs
  coreutils
  bash
  findutils
  rename
  git
  mogenerator
  brew-cask
  tig
  bundler
)

cask_apps=(
  dropbox
)

# colors
black='\[\e[30m\]'
white='\[\e[37m\]'
red='\[\e[31m\]'
green='\[\e[32m\]'
yellow='\[\e[33m\]'
blue='\[\e[34m\]'
magenta='\[\e[35m\]'
cyan='\[\e[36m\]'
none='\[\e[0m\]' # reset color

# formatting
underline='\e[4m'

pline=$(printf "(Line: $LINENO)")

no_internet() {
  cprintn "You don't appear to have an internet connection." $red
  cprintn "Please connect to the internet and try again." $red
  exit 1
}

pcleanup() {
  setcolor $none
  echo ""
}

trap pcleanup EXIT

# print with color and/or formatting
cprint() {
  for i in "${@:2}"; do
    printf "$i"
  done
  
  printf "${1}$none";
}

cprintn () {
  cprint "$@"
  printf "\n"
}

# set color -- don't forget to call setcolor $none to reset
setcolor() { printf $1; }

psudo_access() {
  sudo -v

  while true; do 
    sudo -n true; sleep 60; kill -0 "$$" || exit;
  done 2>/dev/null &

  if [ $? -ne 0 ]; then
    exit 1
  fi
}

pbrew_install_or_update() {
  if test ! $(which brew); then
    printf "Installing homebrew ... "
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" >> /dev/null 2>&1 
    pfinish
    
    printf "Updating OSX tools ... "
    brew tap homebrew/dupes >> /dev/null 2>&1
    brew install homebrew/dupes/grep >> /dev/null 2>&1
    brew tap caskroom/cask
  else 
    printf "Updating brew ... "
    brew update >> /dev/null 2>&1
  fi
  
  pfinish
}

pfinish() {
  if [ $? -eq 0 ]; then
    cprintn "DONE" $green
  else
    cprintn "FAILED" $red
  fi
}

pinstall_do() {
  $1 install $3 > /dev/null  
  pfinish
}

pinstall_exists() {
  cprintn "(already installed)" $blue
}

pinstall_invalid() {
  if [ -z $1 ]; then
    printf "<missing command>"
  fi
  
  setcolor $red
  echo "$@ -- invalid options $pline"
  setcolor $none
  echo "pinstall must contain either 2 or 3 arguments only, example:"
  printf "\n\tpinstall 'gem' 'coreutils'\n"
  printf "\tpinstall 'brew' 'pod' 'cocoapods'\n\n"
  echo "Where \$1 is the installer, \$2 is the installed binary and \$3 is the binary to install."
  echo "In many cases the last 2 arguments will be identical, so the 3rd can be ommitted."
  exit 1
}

# e.g. pinstall 'brew' 'pod' 'cocoapods'
#      pinstall 'brew' 'coreutils'
pinstall() {
  if [[ $# < 2 || $# > 3 ]]; then  
    pinstall_invalid
  fi
  
  local command=$3
  
  if [[ $# == 2 ]]; then
    command=$2
  fi
    
  if [[ $1 == "gem" || $1 == "pip" ]]; then    
    printf "Installing $command ... "
    
    if test ! $(which $2); then
      pinstall_do $1 $2 $command
    else
      pinstall_exists
    fi
    
    return
  fi
  
  if [[ $1 == "brew cask" || $1 == "brew" ]]; then
    info=$($1 info $command)
    search_string="Not installed"
    
    printf "Installing $command ... "
    
    if [[ $info == *"$search_string"* ]]; then
      pinstall_do $1 $2 $command
    else
      pinstall_exists
    fi
    
    return    
  fi
  
  cprintn "Unsupported binary: $1 $pline" $red
}

pbrew_setup() {
  pbrew_install_or_update
}

pinstall_gemapps() {
  for app in ${gem_apps[@]}; do
    pinstall gem $app; 
  done      
  
  pinstall gem pod cocoapods
}

pinstall_brewapps() {  
  for app in ${brew_apps[@]}; do
    pinstall brew $app; 
  done
  
  pinstall brew convert imagemagick
}

pinstall_caskapps() {
  for app in ${cask_apps[@]}; do 
    pinstall "brew cask" $app; 
  done
}

pinstall_pythonapps() {
  pinstall brew pip python
  pinstall pip mackup
}

ask() {
  command="$2"
  
  printf "$1 (y/n) "
  read -s -n 1 response
  
  case $response in
    [yY]) 
    cprintn "YES" $green 
    $2
    ;;
    *)    
    cprintn "NO" $yellow ;;
  esac
}

get_computer_name() {
  printf "Enter the name you would like to use? "
  printf $green
  read COMPUTER_NAME
  printf $none
  sudo scutil --set ComputerName "$COMPUTER_NAME"
  sudo scutil --set HostName "$COMPUTER_NAME"
  sudo scutil --set LocalHostName "$COMPUTER_NAME"
  sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$COMPUTER_NAME"
}

clear_dock_icons() {
  defaults write com.apple.dock persistent-apps -array
}

restart_apps() {
  printf "Restarting some applications in order for their settings to take effect ... "

  find ~/Library/Application\ Support/Dock -name "*.db" -maxdepth 1 -delete
  for app in "Activity Monitor" "Address Book" "Calendar" "Contacts" "cfprefsd" \
  "Dock" "Finder" "Mail" "Messages" "Safari" "SystemUIServer" "Transmission"; do
    killall "${app}" > /dev/null 2>&1
  done

  cprintn "DONE" $green
}

perform_installation() {
  psudo_access
  cprintn "Installation\n" $cyan
  
  pbrew_setup
  pinstall_gemapps
  pinstall_brewapps
  pinstall_caskapps
  pinstall_pythonapps
}

perform_configuration() {
  psudo_access
  cprintn "Configuration\n" $cyan
  
  printf "Automatically quit printer app once the print jobs complete ... "
    defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true
  pfinish
  
  printf "Reveal IP address, hostname, OS version, etc. when clicking the clock in the login window ... "
    sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
  pfinish
  
  printf "Check for software updates daily, not just once per week ... "
    defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1
  pfinish
  
  printf "Disabling hibernation. Speeds up entering sleep mode ... "
    sudo pmset -a hibernatemode 0
  pfinish
  
  printf "Setting standby mode to kick in after 4 hours ... "
    sudo pmset -a standbydelay 14400
  pfinish
  
  printf "Setting a blazingly fast keyboard repeat rate ... "
    defaults write NSGlobalDomain KeyRepeat -int 0
  pfinish
  
  printf "Turn off keyboard illumination when computer is not used for 5 minutes ... "
    defaults write com.apple.BezelServices kDimTime -int 300
  pfinish
  
  printf "Disabling display from automatically adjusting brightness ... "
    sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Display Enabled" -bool false
  pfinish
  
  printf "Disabling keyboard from automatically adjusting brightness ... "
    sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Keyboard Enabled" -bool false
  pfinish
  
  printf "Requiring password immediately after sleep or screen saver begins ... "
    defaults write com.apple.screensaver askForPassword -int 1
    defaults write com.apple.screensaver askForPasswordDelay -int 0
  pfinish
  
  printf "Setting screenshot storage location to ${screenshot_location} ... "
    screenshot_location="${HOME}/Downloads"
    defaults write com.apple.screencapture location -string "${screenshot_location}"
  pfinish
  
  printf "Enabling subpixel font rendering on non-Apple LCDs ... "
    defaults write NSGlobalDomain AppleFontSmoothing -int 2
  pfinish
  
  printf "Enabling Finder status bar by default ... "
    defaults write com.apple.finder ShowStatusBar -bool true
  pfinish
  
  printf "Disabling the warning when changing a file extension ... "
    defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
  pfinish
  
  printf "Disabling creation of .DS_Store files on network volumes ... "
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  pfinish
  
  printf "Disabling disk image verification ... "
    defaults write com.apple.frameworks.diskimages skip-verify -bool true
    defaults write com.apple.frameworks.diskimages skip-verify-locked -bool true
    defaults write com.apple.frameworks.diskimages skip-verify-remote -bool true
  pfinish
  
  printf "Enabling text selection in Quick Look/Preview in Finder by default ... "
    defaults write com.apple.finder QLEnableTextSelection -bool true
  pfinish
  
  printf "Enabling snap-to-grid for icons on the desktop and in other icon views ... "
    /usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
    /usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
    /usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
  pfinish
  
  printf "Setting the icon size of Dock items for optimal size/screen-realestate ... "
    defaults write com.apple.dock tilesize -int 72
  pfinish
  
  printf "Setting Dock to auto-hide and removing the auto-hide delay ... "
    defaults write com.apple.dock autohide -bool true
    defaults write com.apple.dock autohide-delay -float 0
  pfinish
  
  printf "Privacy: Don’t send search queries to Apple ... "
    defaults write com.apple.Safari UniversalSearchEnabled -bool false
    defaults write com.apple.Safari SuppressSearchSuggestions -bool true
  pfinish
  
  printf "Enabling Safari's debug menu ... "
    defaults write com.apple.Safari IncludeInternalDebugMenu -bool true
  pfinish
  
  printf "Making Safari's search banners default to Contains instead of Starts With ... "
    defaults write com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false
  pfinish
  
  printf "Removing useless icons from Safari's bookmarks bar ... "
    defaults write com.apple.Safari ProxiesInBookmarksBar "()"
  pfinish
  
  printf "Enabling the Develop menu and the Web Inspector in Safari ... "
    defaults write com.apple.Safari IncludeDevelopMenu -bool true
    defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
    defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" -bool true
  pfinish
  
  printf "Adding a context menu item for showing the Web Inspector in web views ... "
    defaults write NSGlobalDomain WebKitDeveloperExtras -bool true
  pfinish
  
  printf "Enabling UTF-8 ONLY in Terminal.app and setting the 'Shaps' theme by default ... "
    defaults write com.apple.terminal StringEncodings -array 4
    defaults write com.apple.Terminal "Default Window Settings" -string "Shaps"
    defaults write com.apple.Terminal "Startup Window Settings" -string "Shaps"
  pfinish
  
  printf "Preventing Time Machine from prompting to use new hard drives as backup volume ... "
    defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
  pfinish
  
  incompleteDIR="${HOME}/Downloads/Torrents"
  printf "Use $incompleteDIR"
  printf " to store incomplete downloads ... "
    defaults write org.m0k.transmission UseIncompleteDownloadFolder -bool true
    defaults write org.m0k.transmission IncompleteDownloadFolder -string "$incompleteDIR"
  pfinish
  
  printf "Don't prompt for confirmation before downloading ... "
    defaults write org.m0k.transmission DownloadAsk -bool false
  pfinish
  
  printf "Trash original torrent files ... "
    defaults write org.m0k.transmission DeleteOriginalTorrent -bool true
  pfinish
  
  printf "Hide the donate message ... "
    defaults write org.m0k.transmission WarningDonate -bool false
  pfinish
  
  printf "Hide the legal disclaimer ... "
    defaults write org.m0k.transmission WarningLegal -bool false 
  pfinish
  
  perform_additional_tasks
}

perform_additional_tasks() {
  echo ""
  ask "Would you like to set your computer name (as done via System Preferences)?" get_computer_name
  ask "Would you like to clear all Dock icons?" clear_dock_icons
  echo ""
  restart_apps
}

Reset
cat <<EOF    

                         ''~\`\`
                        ( o o )
+------------------.oooO--(_)--Oooo.------------------+
|                                                     |
|                    .oooO                            |
|                    (   )   Oooo.                    |
+---------------------\ (----(   )--------------------+


Welcome to Primo!

EOF

while getopts ":ic" opt; do
  case $opt in
    i) perform_installation ;;
    c) perform_configuration ;;
    \?)
      cprintn "Invalid option: -$OPTARG\n" $red >&2
      printf "\t-i Install your apps\n"
      printf "\t-c Configure your system\n"
      exit
      ;;
  esac
done

if [ $OPTIND -eq 1 ]; then 
  perform_installation
  echo ""
  perform_configuration
fi

echo ""
echo "------------------"
cprintn "Complete... once you've configured Dropbox run 'mackup' to backup/restore your system" $cyan
