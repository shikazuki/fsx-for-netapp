# fsx-for-netapp

## Initialize
```shell
$ terraform init
$ terraform apply
```

### Get Admin Password
```shell
$ terraform output admin_password
```

## Setup SMB by workgroup

### Create SMB Server
https://docs.netapp.com/ja-jp/ontap/smb-config/create-server-workgroup-task.html
```shell
# Login cifs server.
$ ssh fsxadmin@management.fs-xxxx.fsx.ap-northeast-1.amazonaws.co

# Create SMB server.
cluster1::> vserver cifs create -vserver fsx-netapp -cifs-server SMB_SERVER01 -workgroup workgroup01

# Show the details.
cluster1::> vserver cifs show -vserver fsx-netapp

                                          Vserver: fsx-netapp
                         CIFS Server NetBIOS Name: SMB_SERVER01
                    NetBIOS Domain/Workgroup Name: workgroup01
                      Fully Qualified Domain Name: -
                              Organizational Unit: -
Default Site Used by LIFs Without Site Membership: -
                                   Workgroup Name: workgroup01
                             Authentication Style: workgroup
                CIFS Server Administrative Status: up
                          CIFS Server Description:
                          List of NetBIOS Aliases: -
```

### Create User
https://docs.netapp.com/ja-jp/ontap/smb-config/create-local-user-accounts-task.html
```shell
# Create User.
cluster1::> vserver cifs users-and-groups local-user create -vserver fsx-netapp guest-user

Enter the password:
Confirm the password:

# Show created user.
cluster1::> vserver cifs users-and-groups local-user show
Vserver  User Name                  Full Name  Description
-------- -------------------------- ---------- -------------
vs1      SMB_SERVER01\Administrator            Built-in administrator account
vs1      SMB_SERVER01\guest-user            
```

### Create Group
https://docs.netapp.com/ja-jp/ontap/smb-config/create-local-groups-task.html
```shell
# Create group.
cluster1::> vserver cifs users-and-groups local-group create -vserver fsx-netapp -group-name SMB_SERVER01\guest-users

# Show created group.
cluster1::> vserver cifs users-and-groups local-group show -vserver fsx-netapp
Vserver          Group Name                   Description
---------------- ---------------------------- ----------------------------
fsx-netapp        BUILTIN\Administrators       Built-in Administrators group
fsx-netapp        BUILTIN\Backup Operators     Backup Operators group
fsx-netapp        BUILTIN\Power Users          Restricted administrative privileges
fsx-netapp        BUILTIN\Users                All users
fsx-netapp        SMB_SERVER01\guest-users
```      

### Add User To Group
https://docs.netapp.com/ja-jp/ontap/smb-config/manage-local-group-membership-task.html
```shell
# Add User.
cluster1::> vserver cifs users-and-groups local-group add-members -vserver fsx-netapp -group-name SMB_SERVER01\guest-users -member-names SMB_SERVER01\guest-user
# Remove User.
cluster1::> vserver cifs users-and-groups local-group remove-members -vserver fsx-netapp -group-name SMB_SERVER01\guest-users -member-names SMB_SERVER01\guest-user
```

### Create File Share
https://docs.netapp.com/ja-jp/ontap/smb-config/create-share-task.html
```shell
# Create file share. path args is junction-path name.
cluster1::> vserver cifs share create -vserver fsx-netapp -share-name SHARE1 -path /vol

# Show file share.
cluster1::> vserver cifs share show -share-name SHARE1

Vserver          Share    Path     Properties Comment  ACL
---------------  -------- -------- ---------- -------- -----------
fsx-netapp       SHARE1   /vol     oplocks    -        Everyone / Full Control
                                   browsable
                                   changenotify
                                   show-previous-versions

```
## Mount volume By SMB
This example don't use Active Directory.
We have to use the same guest user through SMB protocol.

### Windows
```ps
# Mount
$ net use Z: \\<svm-domain-name>\SHARE1 <password> /user:guest-user /persistent:YES
# Unmount
$ net use Z: \delete
```

### Linux
```shell
# Install smb client
$ sudo yum install samba-client samba-winbind cifs-utils
# Mount
$ sudo mkdir /mnt/fsx/
$ sudo mount -t cifs //<svm-domain-name>/SHARE1 /mnt/fsx/ -o username=guest-user,domain=SMB_SERVER01
# Unmount
$ sudo umount /mnt/fsx
```

- https://www.suse.com/ja-jp/support/kb/doc/?id=000018669
- https://docs.aws.amazon.com/ja_jp/fsx/latest/ONTAPGuide/managing-volumes.html#volume-security-style
- https://qiita.com/dojineko/items/e6c21f3fe309b5aae694

## FYI : Mount volume by NFS

### Linux
```shell
# Mount
$ sudo mount -t nfs <svm-domain-name>:/vol /mnt/fsx
```

Auto mounting
```/etc/fstab
<svm-dns-name>:/vol /mnt/fsx nfs defaults 0 0
```
https://docs.aws.amazon.com/ja_jp/fsx/latest/ONTAPGuide/attach-linux-client.html

### Windows
Enable nfs v3.
https://docs.netapp.com/ja-jp/ontap/nfs-admin/enable-access-windows-nfs-clients-task.html

```shell
cluster1::>  vserver nfs modify -vserver svm_name -v3-ms-dos-client enabled -mount-rootonly disabled
```
