#!/bin/bash

wrong_arguments () {

  echo -e "\nMissing: arg1 [arg2]\n"
  echo -e " ----------------------------------------------------------------------"
  echo -e "| arg1     | arg2                 | Description                        |"
  echo -e " ----------------------------------------------------------------------"
  echo -e "| install  | core                 | Install Core                       |"
  echo -e "| update   | core / self / check  | Update Core / Core-Control / Check |"
  echo -e "| remove   | core / self          | Remove Core / Core-Control         |"
  echo -e "| secret   | set / clear          | Delegate Secret Set / Clear        |"
  echo -e "| start    | relay / forger / all | Start Core Services                |"
  echo -e "| restart  | relay / forger / all | Restart Core Services              |"
  echo -e "| stop     | relay / forger / all | Stop Core Services                 |"
  echo -e "| logs     | relay / forger / all | Show Core Logs                     |"
  echo -e "| snapshot | create / restore     | Snapshot Create / Restore          |"
  echo -e "| system   | info / update        | System Info / Update               |"
  echo -e "| config   | reset                | Reset Config Files to Defaults     |"
  echo -e " ----------------------------------------------------------------------\n"
  exit 1

}

pm2status () {

   echo $(pm2 describe $1 2>/dev/null)

}

setefile () {

  local envFile="$config/.env"
  touch "$envFile"

  echo "CORE_LOG_LEVEL=$log_level" >> "$envFile" 2>&1
  echo "CORE_DB_HOST=localhost" >> "$envFile" 2>&1
  echo "CORE_DB_PORT=5432" >> "$envFile" 2>&1
  echo "CORE_DB_USERNAME=$USER" >> "$envFile" 2>&1
  echo "CORE_DB_PASSWORD=password" >> "$envFile" 2>&1
  echo "CORE_DB_DATABASE=${name}_$network" >> "$envFile" 2>&1
  echo "CORE_P2P_HOST=0.0.0.0" >> "$envFile" 2>&1
  echo "CORE_P2P_PORT=$p2p_port" >> "$envFile" 2>&1
  echo "CORE_API_HOST=0.0.0.0" >> "$envFile" 2>&1
  echo "CORE_API_PORT=$api_port" >> "$envFile" 2>&1
  echo "CORE_WEBHOOKS_HOST=0.0.0.0" >> "$envFile" 2>&1
  echo "CORE_WEBHOOKS_PORT=$wh_port" >> "$envFile" 2>&1
  echo "CORE_GRAPHQL_HOST=0.0.0.0" >> "$envFile" 2>&1
  echo "CORE_GRAPHQL_PORT=$gql_port" >> "$envFile" 2>&1
  echo "CORE_JSONRPC_HOST=0.0.0.0" >> "$envFile" 2>&1
  echo "CORE_JSONRPC_PORT=$rpc_port" >> "$envFile" 2>&1

}

start () {

  local secrets=$(cat $config/delegates.json | jq -r '.secrets')

  if [ "$1" = "all" ]; then

    local fstatus=$(pm2status "${name}-core-forger" | awk '{print $13}')
    local rstatus=$(pm2status "${name}-core-relay" | awk '{print $13}')

    if [ "$rstatus" != "online" ]; then
      pm2 --name "${name}-core-relay" start $core/packages/core/dist/index.js -- relay --network $network > /dev/null 2>&1
    else
      echo -e "\n${red}Process relay already running. Skipping..."
    fi

    if [ "$secrets" = "[]" ]; then
      echo -e "\n${red}Delegate secret is missing. Forger start aborted!"
    elif [ "$fstatus" != "online" ]; then
      pm2 --name "${name}-core-forger" start $core/packages/core/dist/index.js -- forger --network $network > /dev/null 2>&1
    else
      echo -e "\n${red}Process forger already running. Skipping..."
    fi

    local rstatus=$(pm2status "${name}-core-relay" | awk '{print $13}')

    if [ "$rstatus" != "online" ]; then
      echo -e "\n${red}Process startup failed."
    fi

  else

    local pstatus=$(pm2status "${name}-core-$1" | awk '{print $13}')

    if [[ "$secrets" = "[]" && "$1" = "forger" ]]; then
      echo -e "\n${red}Delegate secret is missing. Forger start aborted!"
    elif [ "$pstatus" != "online" ]; then
      pm2 --name "${name}-core-$1" start $core/packages/core/dist/index.js -- $1 --network $network > /dev/null 2>&1
    else
      echo -e "\n${red}Process $1 already running. Skipping..."
    fi

    local pstatus=$(pm2status "${name}-core-$1" | awk '{print $13}')

    if [[ "$pstatus" != "online" && "$1" = "relay" ]]; then
      echo -e "\n${red}Process startup failed."
    fi

  fi

  pm2 save > /dev/null 2>&1

}

restart () {

  if [ "$1" = "all" ]; then

    local fstatus=$(pm2status "${name}-core-forger" | awk '{print $13}')
    local rstatus=$(pm2status "${name}-core-relay" | awk '{print $13}')

    if [ "$rstatus" = "online" ]; then
      pm2 restart ${name}-core-relay > /dev/null 2>&1
    else
      echo -e "\n${red}Process relay not running. Skipping..."
    fi

    if [ "$fstatus" = "online" ]; then
      pm2 restart ${name}-core-forger > /dev/null 2>&1
    else
      echo -e "\n${red}Process forger not running. Skipping..."
    fi

  else

    local pstatus=$(pm2status "${name}-core-$1" | awk '{print $13}')

    if [ "$pstatus" = "online" ]; then
      pm2 restart ${name}-core-$1 > /dev/null 2>&1
    else
      echo -e "\n${red}Process $1 not running. Skipping..."
    fi

  fi

}

stop () {

  if [ "$1" = "all" ]; then

    local fstatus=$(pm2status "${name}-core-forger" | awk '{print $13}')
    local rstatus=$(pm2status "${name}-core-relay" | awk '{print $13}')

    if [ "$rstatus" = "online" ]; then
      pm2 stop ${name}-core-relay > /dev/null 2>&1
    else
      echo -e "\n${red}Process relay not running. Skipping..."
    fi

    if [ "$fstatus" = "online" ]; then
      pm2 stop ${name}-core-forger > /dev/null 2>&1
    else
      echo -e "\n${red}Process forger not running. Skipping..."
    fi

  else

    local pstatus=$(pm2status "${name}-core-$1" | awk '{print $13}')

    if [ "$pstatus" = "online" ]; then
      pm2 stop ${name}-core-$1 > /dev/null 2>&1
    else
      echo -e "\n${red}Process $1 not running. Skipping..."
    fi

  fi

  pm2 save > /dev/null 2>&1

}

install_deps () {

  sudo apt install -y htop curl build-essential python git nodejs npm libpq-dev ntp gawk jq > /dev/null 2>&1
  sudo npm install -g n grunt-cli pm2 yarn lerna > /dev/null 2>&1
  sudo n 10 > /dev/null 2>&1
  pm2 install pm2-logrotate > /dev/null 2>&1

  local pm2startup="$(pm2 startup | tail -n1)"
  eval $pm2startup > /dev/null 2>&1
  pm2 save > /dev/null 2>&1

}

secure () {

  sudo apt install -y ufw fail2ban > /dev/null 2>&1
  sudo ufw allow 22/tcp > /dev/null 2>&1
  sudo ufw allow ${p2p_port}/tcp > /dev/null 2>&1
  sudo ufw allow ${api_port}/tcp > /dev/null 2>&1
  sudo ufw --force enable > /dev/null 2>&1
  sudo sed -i "/^PermitRootLogin/c PermitRootLogin prohibit-password" /etc/ssh/sshd_config > /dev/null 2>&1
  sudo systemctl restart sshd.service > /dev/null 2>&1

}

install_db () {

  sudo apt install -y postgresql postgresql-contrib > /dev/null 2>&1
  sudo -u postgres psql -c "CREATE USER $USER WITH PASSWORD 'password' CREATEDB;" > /dev/null 2>&1
  dropdb ${name}_$network > /dev/null 2>&1
  createdb ${name}_$network > /dev/null 2>&1

}

install_core () {

  git clone $repo $core -b $branch > /dev/null 2>&1

  if [ -d $HOME/.config ]; then
    sudo chown -R $USER:$USER $HOME/.config > /dev/null 2>&1
  else
    mkdir $HOME/.config > /dev/null 2>&1
  fi

  mkdir $data > /dev/null 2>&1
  cd $core > /dev/null 2>&1

  yarn setup > /dev/null 2>&1
  cp -rf "$core/packages/core/src/config/$network" "$data" > /dev/null 2>&1

  setefile

}

update () {

  cd $core > /dev/null 2>&1
  git pull > /dev/null 2>&1
  yarn setup > /dev/null 2>&1

  local fstatus=$(pm2status "${name}-core-forger" | awk '{print $13}')
  local rstatus=$(pm2status "${name}-core-relay" | awk '{print $13}')

  if [ "$rstatus" = "online" ]; then
    pm2 restart ${name}-core-relay > /dev/null 2>&1
  fi

  if [ "$fstatus" = "online" ]; then
    pm2 restart ${name}-core-forger > /dev/null 2>&1
  fi

}

remove () {

  pm2 delete ${name}-core-forger > /dev/null 2>&1
  pm2 delete ${name}-core-relay > /dev/null 2>&1
  pm2 save > /dev/null 2>&1
  rm -rf $core > /dev/null 2>&1
  rm -rf $data > /dev/null 2>&1
  rm -rf $HOME/.cache/${name}-core > /dev/null 2>&1
  rm -rf $HOME/.local/share/${name}-core > /dev/null 2>&1
  rm -rf $HOME/.local/state/${name}-core > /dev/null 2>&1
  rm -rf /tmp/$USER/${name}-core > /dev/null 2>&1
  dropdb ${name}_$network > /dev/null 2>&1
  sudo ufw delete allow $p2p_port/tcp > /dev/null 2>&1
  sudo ufw delete allow $api_port/tcp > /dev/null 2>&1

}

config_reset () {

  stop all > /dev/null 2>&1
  rm -rf $config > /dev/null 2>&1
  cp -rf "$core/packages/core/src/config/$network" "$data" > /dev/null 2>&1 
  setefile

}

sysinfo () {

  local sockets="$(lscpu | grep "Socket(s):" | head -n1 | awk '{ printf $2 }')"
  local cps="$(lscpu | grep "Core(s) per socket:" | awk '{ printf $4 }')"
  local tpc="$(lscpu | grep "Thread(s) per core:" | awk '{ printf $4 }')"
  local os="$(lsb_release -d | awk '{ for (i=2;i<=NF;++i) printf $i " " }')"
  local cpu="$(lscpu | grep "Model name" | awk '{ for (i=3;i<=NF;++i) printf $i " " }')"
  local mhz="$(lscpu | grep "CPU MHz:" | awk '{ printf $3 }' | cut -f1 -d".")"
  local maxmhz="$(lscpu | grep "CPU max MHz:" | awk '{ printf $4 }' | cut -f1 -d".")"
  local hn="$(hostname --fqdn)"
  local ips="$(hostname --all-ip-address)"

  echo -e "\n${cyan}System: ${nc}$os"
  w | head -n1

  echo -e "\n${cyan}CPU(s): ${nc}${sockets}x ${cpu}with $cps Cores and $[cps*tpc] Threads"
  echo -ne " ${cyan}Total: ${nc}$[sockets*cps] Cores and $[sockets*cps*tpc] Threads"
  if [ -z "$maxmhz" ]; then
    echo -e " @ ${mhz}MHz"
  else
    echo -e " @ ${maxmhz}MHz"
  fi

  echo -e "\n${cyan}Hostname: ${nc}$hn"
  echo -e " ${cyan}IP(s): ${nc}$ips"

  echo -e "${yellow}"
  free -h

  echo -e "${magenta}"
  df -h /

  echo -e "${nc}"

}

sysupdate () {

  sudo apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade -y > /dev/null 2>&1
  sudo apt-get autoremove -y > /dev/null 2>&1
  sudo apt-get autoclean -y > /dev/null 2>&1

}

logs () {

  if [ "$1" = "all" ]; then
    pm2 logs
  else
    pm2 logs ${name}-core-$1
  fi

}

secret () {

  if [ "$1" = "set" ]; then
    local scrt="$2 $3 $4 $5 $6 $7 $8 $9 ${10} ${11} ${12} ${13}"
    jq --arg scrt "$scrt" '.secrets = [$scrt]' $config/delegates.json > delegates.tmp
  else
    jq '.secrets = []' $config/delegates.json > delegates.tmp
  fi

  mv delegates.tmp $config/delegates.json

}

snapshot () {

  if [ "$1" = "restore" ]; then

    local fstatus=$(pm2status "${name}-core-forger" | awk '{print $13}')
    local rstatus=$(pm2status "${name}-core-relay" | awk '{print $13}')

    stop all > /dev/null 2>&1

    dropdb ${name}_$network > /dev/null 2>&1
    createdb ${name}_$network > /dev/null 2>&1
    pg_restore -n public -O -j 8 -d ${name}_$network $HOME/snapshots/${name}_$network > /dev/null 2>&1

    if [ "$rstatus" = "online" ]; then
      start relay $network > /dev/null 2>&1
    fi

    if [ "$fstatus" = "online" ]; then
      start forger $network > /dev/null 2>&1
    fi

  else

    if [ ! -d $HOME/snapshots ]; then
      mkdir $HOME/snapshots
    fi

    pg_dump -Fc ${name}_$network > $HOME/snapshots/${name}_$network

  fi

}

selfremove () {

  cd $HOME > /dev/null 2>&1
  rm -rf $basedir > /dev/null 2>&1
  sed -i '/ccontrol/d' $HOME/.bashrc > /dev/null 2>&1
  sed -i '/cccomp/d' $HOME/.bashrc > /dev/null 2>&1

}

update_info () {

  git fetch > /dev/null 2>&1
  local loc=$(git rev-parse --short @)
  local rem=$(git rev-parse --short @{u})

  echo -e -n "\n${cyan}core-control${nc} v${cyan}${version}${nc} hash: ${cyan}${loc}${nc} status: "

  if [ "$loc" = "$rem" ]; then
    echo -e "${green}current${nc}"
  else
    echo -e "${red}stale${nc}"
  fi

  echo -e ""

  if [ -d $core ]; then

    cd $core > /dev/null 2>&1
    git fetch > /dev/null 2>&1
    local loc=$(git rev-parse --short @)
    local rem=$(git rev-parse --short @{u})
    local corever=$(cat packages/core/package.json | jq -r '.version')

    echo -e -n "${cyan}${name}-core${nc} v${cyan}${corever}${nc} hash: ${cyan}${loc}${nc} status: "

    if [ "$loc" = "$rem" ]; then
      echo -e "${green}current${nc}"
    else
      echo -e "${red}stale${nc}"
    fi

    echo -e ""

  fi

}
