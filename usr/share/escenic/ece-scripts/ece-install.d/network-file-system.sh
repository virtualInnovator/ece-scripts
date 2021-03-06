# module to install & configure network file systems, both server and
# client side.

default_nfs_export_list="/var/exports/multimedia"
default_nfs_mount_point_parent="/mnt"

function get_nfs_configuration() {
  nfs_export_list=${fai_nfs_export_list-$default_nfs_export_list}
  nfs_server_address=${fai_nfs_server_address}
  nfs_allowed_client_network=${fai_nfs_allowed_client_network}
  nfs_client_mount_point_parent=${fai_nfs_client_mount_point_parent-${default_nfs_mount_point_parent}}

  if [ $install_profile_number -eq $PROFILE_NFS_SERVER ]; then
    ensure_variable_is_set fai_nfs_allowed_client_network
  elif [ $install_profile_number -eq $PROFILE_NFS_CLIENT ]; then
    ensure_variable_is_set fai_nfs_server_address
  fi
}

function install_nfs_server() {
  print_and_log "Installing an NFS server on $HOSTNAME ..."
  install_packages_if_missing "portmap nfs-kernel-server nfs-common"
  get_nfs_configuration

  local i=1
  for el in $nfs_export_list; do
    # using no_subtree_check and async to speed up transfers.
    local nfs_opts="(rw,no_subtree_check,sync,fsid=$i)"
    local entry="$el ${nfs_allowed_client_network}${nfs_opts}"
    if [ $(grep "$entry" /etc/exports 2>/dev/null | wc -l) -lt 1 ]; then
      cat >> /etc/exports <<EOF
# added by $(basename $0) @ $(date)
$entry
EOF
    fi
    
    make_dir $el
    run chown ${ece_user}:${ece_group} $el
    i=$(( $i + 1 ))
  done


  # nfs-kernel-server complains on Ubuntu if this directory doesn't exist
  make_dir /etc/exports.d
  
  run /etc/init.d/portmap restart
  run /etc/init.d/nfs-kernel-server restart

  add_next_step "An NFS server has been installed on ${HOSTNAME},"
  add_next_step "NFS exports: $nfs_export_list"
}

function install_nfs_client() {
  print_and_log "Installing an NFS client on $HOSTNAME ..."
  
  install_packages_if_missing "nfs-common"
  get_nfs_configuration

  local mount_point_list=""
  local file=/etc/fstab
  
  for el in $nfs_export_list; do
    local entry="${nfs_server_address}:$el ${nfs_client_mount_point_parent}/$(basename $0) nfs defaults 0 0"
    if [ $(grep "$entry" $file | wc -l) -lt 1 ]; then
      cat >> $file <<EOF
# added by $(basename $el) @ $(date)
${nfs_server_address}:$el ${nfs_client_mount_point_parent}/$(basename $el) nfs defaults 0 0
EOF
    fi

    local mount_point=${nfs_client_mount_point_parent}/$(basename $el)
    make_dir $mount_point
    run mount $mount_point
    mount_point_list="$mount_point $mount_point_list"
  done

  add_next_step "An NFS client has been added to $HOSTNAME"
  add_next_step "NFS mount points: $mount_point_list"
}
