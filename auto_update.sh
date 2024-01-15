#!/bin/bash
# 设置环境变量
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 新的所有者和组，需要替换为实际的用户名和组名
OWNER="root"

# 组名，可以通过命令 cat /etc/group | grep staff 查找
GROUP="staff"

# 本地仓库的路径，替换为实际路径用pwd查找
SITEDIR="/Users/jiahaizhang/Desktop/repo/main"

# 更改目录下文件的所有者和组，排除指定目录
ChangeOwnerExcludeDir() {
    local targetDir=$1
    local newOwner=$2
    local newGroup=$3
    local excludeDir=$4

    # 遍历目标目录下的每个项目
    for item in "$targetDir"/*; do
        # 获取文件或目录的基本名
        local baseItem=$(basename "$item")

        # 如果是排除的目录，则跳过
        if [ "$baseItem" = "$excludeDir" ]; then
            continue
        fi

        # 更改所有者和组
        chown -R "$newOwner:$newGroup" "$item" 
    done
}

# 从远程仓库获取最新代码，并强制覆盖本地修改
CoverLocalModel() {
    sudo -u root git fetch --all && sudo -u root git reset --hard $1
    # chown -R kakaftpuser:www ./
}

# 拉取指定分支的最新代码
PullUI() {
    cd "$SITEDIR"
    CheckGitStatus "" "${1}"
    pullStatus=$(sudo -u root git pull)
    result=$(echo "$pullStatus" | grep "Updating")
    if [ "$result" != "" ] ; then
        Logs "UI_${1}:有更新"
        # 设置权限，忽略掉.git目录，git的配置文件权限还是要用root，网站文件的权限还是要www组，要不然nginx访问会提示没有权限
        ChangeOwnerExcludeDir "$SITEDIR/${1}/" "$OWNER" "$GROUP" ".git"
        # chown -R kakaftpuser:www /www/wwwroot/${1}/ && chmod -R o-r-w-x /www/wwwroot/${1}/ && chmod -R g-w /www/wwwroot/${1}/
    fi
}

# 定时任务函数
DoCrond() {
    PullUI "lesson-git" "remotes/origin/main"
    sleep 10
}

# 检查Git状态，处理本地修改和未合并的情况
CheckGitStatus() {
    gitStatus=$(sudo -u root git status 2>&1)
    gitStatusTips=$(Logs "$gitStatus" | grep "Changes not staged for commit")
    gituUnmergedTips=$(Logs "$gitStatus" | grep "have unmerged")
    if [ "$gitStatusTips" != ""  ] ; then
        Logs "本地有修改,强制覆盖."
        CoverLocalModel "${1}"
        # else
        #   Logs "没有修改"
    fi
    if [ "$gituUnmergedTips" != ""  ] ; then
        # sudo -u root git merge --abort
        sudo -u root git merge --quit
        sudo -u root git config pull.rebase true
        Logs "放弃本地合并."
    fi
    sleep 2
}

# 记录日志
Logs() {
    TIME_STAMP=$(date "+%Y-%m-%d %T")
    echo "${TIME_STAMP}:$1"
}

# 无限循环执行定时任务
while true
do
    DoCrond
done

