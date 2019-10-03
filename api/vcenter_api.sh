#!/bin/sh

folder="/data/api/export"
vmware="$folder/vmware"

curl="curl -k -s -X"
appjson="Accept: application/json"

##### VARIABLE VCENTER #####
vcenter_user="administrator@domain.local"
vcenter_password="password"

vcenter_host="vcenter.domain.local"
vcenter_url="https://$vcenter_host/rest"

vcenter_gettoken=$($curl POST -H "$appjson" -H "Content-Type: application/json" --basic -u "$vcenter_user:$vcenter_password" "$vcenter_url/com/vmware/cis/session" | jq -r ".value")
vcenter_token="vmware-api-session-id: $vcenter_gettoken"

##### VCENTER API #####
vcenter_getdatacenter=$($curl GET -H "$appjson" -H "$vcenter_token" "$vcenter_url/vcenter/datacenter" | jq -r '.value[] | "\(.datacenter);\(.name)"')

##### DATACENTER #####
export_datacenter=$(
  echo "DATACENTER_ID;DATACENTER_NAME"
  for vcenter_datacenter in $(echo "$vcenter_getdatacenter");
  do
    datacenter_id=$(echo "$vcenter_datacenter" | awk -F ";" '{print $1}')
    datacenter_name=$(echo "$vcenter_datacenter" | awk -F ";" '{print $2}')
    echo "$datacenter_id;$datacenter_name"
  done
)

##### HOST ESXI #####
export_host=$(
  echo "DATACENTER_ID;DATACENTER_NAME;ESXI_ID;ESXI_NAME;ESXI_POWER"
  for vcenter_datacenter in $(echo "$vcenter_getdatacenter");
  do
    datacenter_id=$(echo "$vcenter_datacenter" | awk -F ";" '{print $1}')
    datacenter_name=$(echo "$vcenter_datacenter" | awk -F ";" '{print $2}')
    vcenter_getesxi=$($curl GET -H "$appjson" -H "$vcenter_token" "$vcenter_url/vcenter/host?filter.datacenters=$datacenter_id" | jq -r '.value[] | "\(.host);\(.name)" ')
      for vcenter_esxi in $(echo "$vcenter_getesxi");
      do
        esxi_id=$(echo "$vcenter_esxi" | awk -F ";" '{print $1}')
        esxi_name=$(echo "$vcenter_esxi" | awk -F ";" '{print $2}')
        esxi_power=$($curl GET -H "$appjson" -H "$vcenter_token" "$vcenter_url/vcenter/host?filter.datacenters=$datacenter_id&filter.hosts=$esxi_id" | jq -r ".value[].power_state")
        echo "$datacenter_id;$datacenter_name;$esxi_id;$esxi_name;$esxi_power"
      done
  done
)

##### DATASTORE #####
export_datastore=$(
  echo "DATACENTER_ID;DATACENTER_NAME;DATASTORE_ID;DATASTORE_NAME;DATASTORE_TYPE;DATASTORE_SIZE;DATASTORE_FREE"
  for vcenter_datacenter in $(echo "$vcenter_getdatacenter");
  do
    datacenter_id=$(echo "$vcenter_datacenter" | awk -F ";" '{print $1}')
    datacenter_name=$(echo "$vcenter_datacenter" | awk -F ";" '{print $2}')
    vcenter_getdatastore=$($curl GET -H "$appjson" -H "$vcenter_token" "$vcenter_url/vcenter/datastore?filter.datacenters=$datacenter_id" | jq -r '.value[] | "\(.datastore);\(.name);\(.type);\(.capacity);\(.free_space)"')
      for vcenter_datastore in $(echo "$vcenter_getdatastore");
      do
        datastore_id=$(echo "$vcenter_datastore" | awk -F ";" '{print $1}')
        datastore_name=$(echo "$vcenter_datastore" | awk -F ";" '{print $2}')
        datastore_type=$(echo "$vcenter_datastore" | awk -F ";" '{print $3}')
        datastore_sizeget=$(
          datastore_size=$(echo "$vcenter_datastore" | awk -F ";" '{print $4}')
          datastore_sizeconv=$(($datastore_size/1024/1024/1024))
          echo "$datastore_sizeconv GB"
        )
        datastore_freeget=$(
          datastore_free=$(echo "$vcenter_datastore" | awk -F ";" '{print $5}')
          datastore_freeconv=$(($datastore_free/1024/1024/1024))
          echo "$datastore_freeconv GB"      
        )
        echo "$datacenter_id;$datacenter_name;$datastore_id;$datastore_name;$datastore_type;$datastore_sizeget;$datastore_freeget"
      done
  done
)

##### VM LIST #####
export_vm=$(
  echo "DATACENTER_ID;DATACENTER_NAME;ESXI_ID;ESXI_NAME;VM_ID;VM_NAME;VM_VERSION;VM_GUEST_OS;VM_CPU;VM_MEMORY;VM_DISK;VM_NETWORK;VM_POWER"
  for vcenter_datacenter in $(echo "$vcenter_getdatacenter");
  do
    datacenter_id=$(echo "$vcenter_datacenter" | awk -F ";" '{print $1}')
    datacenter_name=$(echo "$vcenter_datacenter" | awk -F ";" '{print $2}')
    vcenter_getesxi=$($curl GET -H "$appjson" -H "$vcenter_token" "$vcenter_url/vcenter/host?filter.datacenters=$datacenter_id" | jq -r '.value[] | "\(.host);\(.name)" ')
    for vcenter_esxi in $(echo "$vcenter_getesxi");
    do
      esxi_id=$(echo "$vcenter_esxi" | awk -F ";" '{print $1}')
      esxi_name=$(echo "$vcenter_esxi" | awk -F ";" '{print $2}')
      vm_get=$($curl GET -H "$appjson" -H "$vcenter_token" "$vcenter_url/vcenter/vm?filter.hosts=$esxi_id" | jq -r ".value[].vm")
      for esxi_vm in $(echo "$vm_get");
      do
        vm_name=$($curl GET -H "$appjson" -H "$vcenter_token" "$vcenter_url/vcenter/vm/$esxi_vm" | jq -r ".value.name")
        vm_version=$($curl GET -H "$appjson" -H "$vcenter_token" "$vcenter_url/vcenter/vm/$esxi_vm" | jq -r ".value.hardware.version")
        vm_guestos=$($curl GET -H "$appjson" -H "$vcenter_token" "$vcenter_url/vcenter/vm/$esxi_vm" | jq -r ".value.guest_OS")
        vm_cpuget=$(
          vm_cpu=$($curl GET -H "$appjson" -H "$vcenter_token" "$vcenter_url/vcenter/vm/$esxi_vm" | jq -r ".value.cpu.count")
          echo "$vm_cpu VCPU"
        )
        vm_memoryget=$(
          vm_memory=$($curl GET -H "$appjson" -H "$vcenter_token" "$vcenter_url/vcenter/vm/$esxi_vm" | jq -r ".value.memory.size_MiB")
          vm_memoryconv=$(($vm_memory/1024))
          echo "$vm_memoryconv GB"
        )
        vm_diskget=$(
          vm_disk=$($curl GET -H "$appjson" -H "$vcenter_token" "$vcenter_url/vcenter/vm/$esxi_vm" | jq -r ".value.disks[].value.capacity")
          vm_disknum=$(echo "$vm_disk" | wc | awk '{print $1}')
          vm_disksum=$(echo "$vm_disk" | awk '{s+=$1} END {print s}')
          vm_diskconv=$(($vm_disksum/1024/1024/1024))
          echo "HDD: $vm_disknum SIZE: $vm_diskconv GB"
        )
        vm_networkget=$(
          vm_network=$($curl GET -H "$appjson" -H "$vcenter_token" "$vcenter_url/vcenter/vm/$esxi_vm" | jq -r ".value.nics[].value.label")
          vm_networknum=$(echo "$vm_network" | wc | awk '{print $1}')
          echo "NICS: $vm_networknum"
        )
        vm_power=$($curl GET -H "$appjson" -H "$vcenter_token" "$vcenter_url/vcenter/vm/$esxi_vm" | jq -r '.value.power_state')
        echo "$datacenter_id;$datacenter_name;$esxi_id;$esxi_name;$esxi_vm;$vm_name;$vm_version;$vm_guestos;$vm_cpuget;$vm_memoryget;$vm_diskget;$vm_networkget;$vm_power"
      done
    done
  done
)

vcenter_datacenternum=$(
  datacenternum=$(echo "$export_datacenter" | wc | awk '{print $1}')
  num=$(($datacenternum-1))
  echo "$num"
  )
vcenter_datastorenum=$(
  datastorenum=$(echo "$export_datastore" | wc | awk '{print $1}')
  num=$(($datastorenum-1))
  echo "$num"
  )
vcenter_hostnum=$(
  hostnum=$(echo "$export_host" | wc | awk '{print $1}')
  num=$(($hostnum-1))
  echo "$num"
  )
vcenter_vmnum=$(
  vmnum=$(echo "$export_vm" | wc | awk '{print $1}')
  num=$(($vmnum-1))
  echo "$num"
  )

##### EXPORT INFORMATION #####
rm $vmware/vcenter_all_export.csv
export_all=$(
  echo "List of DATACENTER"
  echo "$export_datacenter"
  echo " "
  echo "List of HOSTS"
  echo "$export_host"
  echo " "
  echo "List of DATASTORE"
  echo "$export_datastore"
  echo " "
  echo "List of VMs"
  echo "$export_vm"
  echo " "
  echo " "
  echo "Number of DATACENTER: $vcenter_datacenternum"
  echo "Number of HOST: $vcenter_hostnum"
  echo "Number of DATASTORE: $vcenter_datastorenum"
  echo "Number of VMs: $vcenter_vmnum"
)
echo "$export_all" >> $vmware/vcenter_all_export.csv