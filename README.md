This is a minimal repro of a gVisor bug that causes a directory to lose its setgid bit when it's modified and copied into the overlay2 layer.

First we build:
```
docker buildx build . -t overlay-setgid
```

Then we create a directory inside `/opt/setgid-test`. At container start up, the directory has the setgid bit.

```
> docker run --runtime=runsc --cap-add=all -i overlay-setgid:latest bash -c 'stat /opt/setgid-test && mkdir /opt/setgid-test/dir && stat /opt/setgid-test'
  File: /opt/setgid-test
  size: 4096            Blocks: 8          IO Block: 4096   directory
Device: 13h/19d Inode: 23          Links: 1
Access: (2775/drwxrwsr-x)  Uid: (    0/    root)   Gid: ( 1001/testuser)
Access: 2026-01-21 20:21:25.140062801 +0000
Modify: 2026-01-21 20:21:24.725064180 +0000
Change: 2026-01-21 20:21:25.096807222 +0000
 Birth: 1970-01-01 00:00:00.000000000 +0000
  File: /opt/setgid-test
  size: 60              Blocks: 0          IO Block: 4096   directory
Device: 13h/19d Inode: 23          Links: 1
Access: (0775/drwxrwxr-x)  Uid: (    0/    root)   Gid: ( 1001/testuser)
Access: 2026-01-21 20:21:25.140062801 +0000
Modify: 2026-01-21 20:31:54.006969103 +0000
Change: 2026-01-21 20:31:54.006969103 +0000
 Birth: -
```

`/opt/setgid-test` starts with `2775/drwxrwsr-x` and after a child directory is added it unexpectedly changes to `0775/drwxrwxr-x`, losing its setgid bit. I assume the size change has something to do with copy-on-write copying the file into the overlay.

Using `runc` instead gives the expected result:

```
> docker run --runtime=runc --cap-add=all -i overlay-setgid:latest bash -c 'stat /opt/setgid-test && mkdir /opt/setgid-test/dir && stat /opt/setgid-test'
  File: /opt/setgid-test
  size: 4096            Blocks: 8          IO Block: 4096   directory
Device: 51h/81d Inode: 36179966    Links: 1
Access: (2775/drwxrwsr-x)  Uid: (    0/    root)   Gid: ( 1001/testuser)
Access: 2026-01-21 20:21:25.140062801 +0000
Modify: 2026-01-21 20:21:24.725064180 +0000
Change: 2026-01-21 20:21:25.096807222 +0000
 Birth: 2026-01-21 20:21:25.096807222 +0000
  File: /opt/setgid-test
  size: 4096            Blocks: 8          IO Block: 4096   directory
Device: 51h/81d Inode: 36179966    Links: 1
Access: (2775/drwxrwsr-x)  Uid: (    0/    root)   Gid: ( 1001/testuser)
Access: 2026-01-21 20:21:25.140062801 +0000
Modify: 2026-01-21 20:37:09.546316375 +0000
Change: 2026-01-21 20:37:09.546316375 +0000
 Birth: 2026-01-21 20:37:09.546316375 +0000
 ```

 Disabling overlay2 also gives the expected result:

 ```
> cat /etc/docker/daemon.json
{
  "features": {
    "buildkit": true
  },
  "runtimes": {
    "runsc": {
      "path": "/usr/local/bin/runsc",
      "runtimeArgs": [
        "--overlay2=none"
      ]
    }
  }
}

> sudo systemctl restart docker
 ```

 ```
 > docker run --runtime=runsc --cap-add=all -i overlay-setgid:latest bash -c 'stat /opt/setgid-test && mkdir /opt/setgid-test/dir && stat /opt/setgid-test'
  File: /opt/setgid-test
  size: 4096            Blocks: 8          IO Block: 4096   directory
Device: 11h/17d Inode: 44          Links: 1
Access: (2775/drwxrwsr-x)  Uid: (    0/    root)   Gid: ( 1001/testuser)
Access: 2026-01-21 20:21:25.140062801 +0000
Modify: 2026-01-21 20:21:24.725064180 +0000
Change: 2026-01-21 20:21:25.096807222 +0000
 Birth: 1970-01-01 00:00:00.000000000 +0000
  File: /opt/setgid-test
  size: 4096            Blocks: 8          IO Block: 4096   directory
Device: 11h/17d Inode: 44          Links: 2
Access: (2775/drwxrwsr-x)  Uid: (    0/    root)   Gid: ( 1001/testuser)
Access: 2026-01-21 20:21:25.140062801 +0000
Modify: 2026-01-21 20:45:11.605115401 +0000
Change: 2026-01-21 20:45:11.605115401 +0000
 Birth: 1970-01-01 00:00:00.000000000 +0000
```

 ## Version Information

 ```
 > docker version
 Client:
 Version:           28.5.2
 API version:       1.51
 Go version:        go1.25.3 X:nodwarf5
 Git commit:        ecc694264d
 Built:             Wed Nov  5 19:24:39 2025
 OS/Arch:           linux/amd64
 Context:           default

Server:
 Engine:
  Version:          28.5.2
  API version:      1.51 (minimum version 1.24)
  Go version:       go1.25.3 X:nodwarf5
  Git commit:       89c5e8fd66
  Built:            Wed Nov  5 19:24:39 2025
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          v2.2.0
  GitCommit:        1c4457e00facac03ce1d75f7b6777a7a851e5c41.m
 runc:
  Version:          1.3.3
  GitCommit:
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0
```

```
> runsc --version
runsc version release-20251020.0
spec: 1.1.0-rc.1
```

```
> cat /etc/docker/daemon.json
{
  "features": {
    "buildkit": true
  },
  "runtimes": {
    "runsc": {
      "path": "/usr/local/bin/runsc",
      "runtimeArgs": []
    }
  }
}
```