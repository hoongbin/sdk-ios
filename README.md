# BetaDataSDK

BetaData是数据统计的SDK
## 案例

运行这个工程, 先 clone the repo, 之后在工程根目录下运行  `pod install` 

## 依赖
* iOS8以上


## 安装

BetaDataSDK可以通过[CocoaPods](https://cocoapods.org)获得。安装
它，只需添加以下行到您的Podfile:

```ruby
pod 'BetaDataSDK'
```

## 升级命令
```bash
// git 操作
git pull origin master
git add .
git commit -m "提交记录描述"
git push origin master
git tag '1.2.14'
git push --tags
// pod 操作 - 报送到远端repo里面(时间久一点,因为要build一遍工程,检测错误)
pod repo push BTSpec BetaDataSDK.podspec --allow-warnings
注: 如果没有添加过BTSpec这个repo, 那么要先添加
pod repo add BTSpec http://code.mocaapp.cn/betadata/sdk-ios-specs.git
```


## 更新记录
|版本|更新信息|开发者|更新时间|
|---|---|---|---||
|1.2.8|增加用户属性signature|任成|2020-01-10|
|1.2.9|deviceId获取机制更改成idfa,idfv,uuid|任成|2020-02-11|
|1.2.10|清理登录/注册事件|任成|2020-03-24|
|1.2.11|pageView事件title更新获取机制:btTitle>title>titleView.title|任成|2020-03-24|
|1.2.12|为UIView增加btTitle属性|任成|2020-03-26|
|1.2.13|修复trackVC增加忽略限制;累加黑名单VC|任成|2020-03-28|
|1.2.14|修复bundle文件引入问题|任成|2020-04-02|
|1.2.15|修复WMPageController组件的引入问题|任成|2020-04-02|
|1.2.16|如更换AppId, 则清除本地待track的Event|任成|2020-04-02|
|1.2.17|增加支付预制事件|任成|2020-04-28|
|1.2.18|暴露API-检测黑名单Controller|任成|2020-04-29|
|1.2.19|将UIWebView替换成WKWebView|任成|2020-05-20|

## 作者

Zhou Kang, dev.zhoukang@gmail.com
Ren Cheng, rencheng11@icloud.com

## 许可

BetaDataSDK在MIT许可下可用。有关更多信息，请参见许可文件。
