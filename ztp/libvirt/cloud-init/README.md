##### Validate user-data syntax
    cloud-init devel schema --config-file user-data

##### Build cloud-init ISO
    mkisofs -o cidata.iso -V cidata -J -r user-data meta-data