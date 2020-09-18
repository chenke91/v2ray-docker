### 进入项目目录

> cd /path/v2ray-docker

### 启动初始化脚本

> ./init-letsencrypt.sh

    # 依次输入 域名/v2ray uuid/v2ray path/邮箱

    [root@VM-0-13-centos v2ray-docker]# ./init-letsencrypt.sh
    请输入域名(必填):
    请输入v2ray uuid(必填):
    请输入v2ray path(默认 /current/user):
    请输入邮箱(选填):

### 启动服务

> docker-compose up -d