# 微信红包助手实现（适合 iOS 非越狱用户）
Wechat Red Envelope Assitant for iOS non-jailbreak users.

##准备工作
首先需要一个没有壳的微信ipa包，这个可以从PP助手上下载越狱版本的包，我当前下载的版本是6.5.4.34，iOS系统最低需要7.0。下载微信ipa包后把后缀名改为zip进行解压，解压得到的Payload文件夹里有真正的包Wechat.app，右键Show Package Contents进入包内可以看到包内的资源，其中微信的可执行文件叫做WeChat这个文件。命令行中用file命令查看WeChat文件，可以看到有2种架构分别是armv7和arm64的。

``` shell
 ➜  WeChat.app file WeChat
WeChat: Mach-O universal binary with 2 architectures
WeChat (for architecture armv7):	Mach-O executable arm
WeChat (for architecture arm64):	Mach-O 64-bit executable
```
微信包中文件夹Watch和PlugIns里还有一些其他的可执行文件和扩展包，暂时用不到可以删除（自己签名也可以，但是为了防止签名失败，删除更保险一点）。这个时候可以对WeChat.app进行签名并装入手机看是否会闪退，签名可以通过命令codesign或使用GUI工具 [ios-app-signer](https://github.com/DanTheMan827/ios-app-signer)。 我的7P上装了从AppStore上下载的微信，直接装自签名的包会导致两个微信都没有网络。于是尝试用lipo命令删除Wechat中的arm64包，仅保留一个和armv7包，再通过Xcode -> Devices，选择设备并安装重签名微信的包，这个时候AppStore的微信和自签名的微信能同时在手机上运行了。

``` shell
lipo WeChat -thin armv7 -output WeChat
```

##逻辑层的实现
在iPhone上成功运行自签名的微信后，就可以开始尝试注入了。注入的可以用框架 [CaptainHook](https://github.com/rpetrich/CaptainHook)，这里就不在细说。最开始我看到了east520的github项目[AutoGetRedEnv](https://github.com/east520/AutoGetRedEnv)，用CaptainHook给[CMessageMgr AsyncOnAddMsg:MsgWrap:]加了一个勾子，CMessageMgr是一个广义的消息管理类，每当收到新消息时，都会要异步更新数据，就会调用方法[CMessageMgr AsyncOnAddMsg:MsgWrap:]，方法会传入消息实例，包含了消息的类型、发送者、发送时间等信息，如果这个消息是红包，那就调用打开红包的方法 [WCRedEnvelopesLogicMgr OpenRedEnvelopesRequest:]。装上去，设置了抢红包的延时，试了一下，红包能成功抢到，但是过了一会儿就被检测到说使用了红包插件，然后就被强行登出，删除重装后还是无效，说明肯定是服务器端有这个检测的逻辑。微信红包出来这么久了，反抢红包插件的应该还是比较成熟了，肯定会对事件进行监控，如果发现没有点击事件但是红包被抢了，那肯定是有辅助工具。早期的微信版本可能还没有那么多的反辅助工具的检测逻辑，所以我猜想如果把微信的版本号改掉，服务器端就不会对事件进行检测了，不过后来看到微信对抢红包的最低版本是有限制的，应该是把这条路给封了。逻辑层的辅助工具比较底层，开销小，方便找到，但是也容易被ban，所以只能从UI模拟的方法来尝试了。

##UI层的实现
因为手上没有越狱的机器，所以动态分析微信的运行框架并不是很方便，不过可以先用 [class-dump](https://github.com/nygard/class-dump) 导出类，找到对应的ViewController再分析，不过由于类太多了，并不能直接找到。看了下抢红包界面，我觉得ViewController应该是push进来的，所以我给UINavigationController的pushViewController加了一个勾子，每当视图有push的时候便打印出来。日志工具使用了 [NSLogger](https://github.com/fpillet/NSLogger)，可以将App中的运行日志发送到局域网内的 NSLogger Client端，自动查找无需配置任何东西。

__具体实现的说明TODO。__


##免责声明
本软件仅供学习交流使用，为防止不当使用，所上传的代码非完整版，仅供参考。