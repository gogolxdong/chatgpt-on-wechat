import puppy,re,QRgen, taskpools
import strformat, os, asyncdispatch, strutils, httpclient, json, times, cookies, httpcore, tables, sequtils

const USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36 NetType/WIFI MicroMessenger/7.0.20.1781(0x6700143B) WindowsWechat(0x63090551) XWEB/8211 Flue"
const UOS_PATCH_CLIENT_VERSION = "2.0.0"
const UOS_PATCH_EXTSPAM = "Go8FCIkFEokFCggwMDAwMDAwMRAGGvAESySibk50w5Wb3uTl2c2h64jVVrV7gNs06GFlWplHQbY/5FfiO++1yH4ykCyNPWKXmco+wfQzK5R98D3so7rJ5LmGFvBLjGceleySrc3SOf2Pc1gVehzJgODeS0lDL3/I/0S2SSE98YgKleq6Uqx6ndTy9yaL9qFxJL7eiA/R3SEfTaW1SBoSITIu+EEkXff+Pv8NHOk7N57rcGk1w0ZzRrQDkXTOXFN2iHYIzAAZPIOY45Lsh+A4slpgnDiaOvRtlQYCt97nmPLuTipOJ8Qc5pM7ZsOsAPPrCQL7nK0I7aPrFDF0q4ziUUKettzW8MrAaiVfmbD1/VkmLNVqqZVvBCtRblXb5FHmtS8FxnqCzYP4WFvz3T0TcrOqwLX1M/DQvcHaGGw0B0y4bZMs7lVScGBFxMj3vbFi2SRKbKhaitxHfYHAOAa0X7/MSS0RNAjdwoyGHeOepXOKY+h3iHeqCvgOH6LOifdHf/1aaZNwSkGotYnYScW8Yx63LnSwba7+hESrtPa/huRmB9KWvMCKbDThL/nne14hnL277EDCSocPu3rOSYjuB9gKSOdVmWsj9Dxb/iZIe+S6AiG29Esm+/eUacSba0k8wn5HhHg9d4tIcixrxveflc8vi2/wNQGVFNsGO6tB5WF0xf/plngOvQ1/ivGV/C1Qpdhzznh0ExAVJ6dwzNg7qIEBaw+BzTJTUuRcPk92Sn6QDn2Pu3mpONaEumacjW4w6ipPnPw+g2TfywJjeEcpSZaP4Q3YV5HG8D6UjWA4GSkBKculWpdCMadx0usMomsSS/74QgpYqcPkmamB4nVv1JxczYITIqItIKjD35IGKAUwAA=="

const baseUrl = "https://login.weixin.qq.com"
var r= fetch(&"{baseUrl}/jslogin?appid=wx782c26e4c19acffb&fun=new&redirect_uri=https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxnewloginpage?mod=desktop&lang=zh_CN", headers = @[("User-Agent", USER_AGENT)])

var loginInfo = %*{"BaseRequest": {"Skey":"","Uin":"","Sid":""}}

var isLoggedIn = false

template webInit() :untyped {.dirty.} = 
    var now = now().toTime().toUnix()
    var webInitUrl = &"{syncUrl}/webwxinit?r={now}&pass_ticket={passTicket[0]}"
    echo "webInitUrl:",webInitUrl
    var initHeader = @[("ContentType", "application/json; charset=UTF-8"), ("User-Agent", USER_AGENT)]
    var data = %*{"BaseRequest": loginInfo["BaseRequest"]}
    var requestBody = $ data
    
    var initResponse = client.request(webInitUrl, HttpPost, body = requestBody, headers = initHeader.newHttpHeaders)
    var initBody = parseJson initResponse.body

    var contactList = initBody["ContactList"]

    var chootRoom = newJArray()
    for c in contactList:
        if "@@" in c["UserName"].getStr:
            chootRoom.add c

    loginInfo{"InviteStartCount"} = initBody["InviteStartCount"]
    loginInfo{"User"} = initBody["User"]
    loginInfo{"SyncKey"} = initBody["SyncKey"]
    var syncKeys = initBody["SyncKey"]["List"].mapIt($(it["Key"].getInt) & "_" & $(it["Val"].getInt)).join("|")
    loginInfo{"synckey"} = %syncKeys

template syncCheck() :untyped {.dirty.} = 
        while true:
            var syncUrl = loginInfo{"syncUrl"}.getStr
            var wxsid = loginInfo{"wxsid"}.getStr
            var skey = loginInfo{"skey"}.getStr
            var passTicket = loginInfo{"passTicket"}.getStr
            if syncUrl != "":
                var syncCheckUrl = &"{syncUrl}/synccheck"
                var client = newHttpClient()
                var data = %*{"r": now().toTime().toUnix() * 1000, 
                    "skey": loginInfo{"skey"}.getStr, 
                    "sid": loginInfo{"wxsid"},
                    "uin": loginInfo{"wxuin"}, "deviceid": 0, 
                    "synckey": loginInfo{"synckey"}
                }
                var response = client.request(syncCheckUrl, HttpPost, body = $ data, headers = {"User-Agent": USER_AGENT}.newHttpHeaders)
                # if response.body =~ re"""window.synccheck={retcode:"(\d+)",selector:"(\d+)"}""":
                #     echo "synccheck:", matches
                #     if matches.len == 0 or matches[0] != "0":
                #         echo "Unexpected sync check result"

                var wxSyncUrl = &"{syncUrl}/webwxsync?sid={wxsid}&skey={skey}&pass_ticket={passTicket}"
                data = %*{"BaseRequest": loginInfo["BaseRequest"], 
                        "SyncKey": loginInfo["SyncKey"], 
                        "rr": now().toTime().toUnix()}
                # echo "webwxsync: ", wxSyncUrl, " sync request data:", $data

                var headers = @[("ContentType", "application/json; charset=UTF-8"), ("User-Agent", USER_AGENT)]
                # var client = newHttpClient()
                var syncResponse = client.request(wxSyncUrl, HttpPost, body = $data, headers = headers.newHttpHeaders)
                var syncBody = parseJson syncResponse.body
                if syncBody["BaseResponse"]["Ret"].getInt != 0:
                    echo syncBody["BaseResponse"]["Ret"]
                loginInfo{"SyncKey"} = syncBody["SyncKey"]
                loginInfo{"synckey"} = %syncBody["SyncCheckKey"]["List"].mapIt(it["Key"].getStr &"_"& it["Val"].getStr).join("|")
                # echo "syncBody:",syncBody

                var actualOpposite:JsonNode
                for m in syncBody["AddMsgList"]:
                    var msgType = m["MsgType"].getInt
                    if msgType in [1,3, 47]:
                        echo "msgType:",m
                        if msgType in [3,47]:
                            var msgId = m["NewMsgId"].getInt
                            var downloadUrl = &"{syncUrl}/webwxgetmsgimg?msgid={msgId}&skey={skey}"
                            echo downloadUrl
                            var headers = @[ ("User-Agent", USER_AGENT)]
                            var downloadResponse = client.request(downloadUrl, HttpGet, headers = headers.newHttpHeaders)
                            echo "downloadResponse:",downloadResponse.body, " ", downloadResponse.code
                            if downloadResponse.code == Http200:
                                writeFile(&"/tmp/{msgId}", downloadResponse.body)
                        var fromUserName = m["FromUserName"].getStr
                        var toUserName = m["ToUserName"].getStr
                        if  fromUserName == loginInfo["User"]["UserName"].getStr:
                            actualOpposite = m["ToUserName"]
                        else:
                            actualOpposite = m["FromUserName"]
                        if "@@" in fromUserName or "@@" in toUserName:
                            if m["Content"].getStr =~ re"(@[0-9a-z]*?):<br/>(.*)$":
                                var actualUserName = matches[0]
                                var content = matches[1]
                        # elif fromUserName == loginInfo["User"]["UserName"].getStr:
                client.close

            sleep(1000)

proc checkLogin(uuid:string) = 
    {.gcsafe.}:
        var loginUrl = &"{baseUrl}/cgi-bin/mmwebwx-bin/login?loginicon=true&uuid={uuid}"
        var client = newHttpClient(maxRedirects = 0)
        defer: client.close()
        while not isLoggedIn:
            var loginResult = fetch(loginUrl)
            var lines = loginResult.splitLines
            if lines.len == 2 and lines[1] =~ re"""window.redirect_uri="(\S+)";""":
                echo matches
                var redirectUrl = matches[0]
                var redirectHeaders =  @[("User-Agent",USER_AGENT),("client-version",UOS_PATCH_CLIENT_VERSION),("extspam",UOS_PATCH_EXTSPAM),("referer", "https://wx.qq.com/?&lang=zh_CN&target=t")]
                var loginResponse = client.request(redirectUrl, headers= newHttpHeaders redirectHeaders)
                var loginBody = loginResponse.body
                echo "loginBody:", loginBody, " ", loginResponse.headers
                var wxsid = ""
                var wxuin = ""
                for k in  loginResponse.headers.table["set-cookie"]:
                    if k =~ re"wxsid=(\S+);.*":
                        wxsid= matches[0]
                    if k =~ re"wxuin=(\d+);.*":
                        wxuin = matches[0]
        
                var skey:array[1,string]
                discard loginBody.match(re".*<skey>(.*?)</skey>.*", skey)
                echo "skey:", skey[0]
                loginInfo["BaseRequest"]["Skey"] = if skey.len != 0 : %skey[0] else: %""
                loginInfo["BaseRequest"]["Uin"] = %wxuin
                loginInfo["BaseRequest"]["Sid"] = %wxsid

                loginInfo{"skey"} = %skey[0]
                loginInfo{"wxuin"} = %wxuin
                loginInfo{"wxsid"} = %wxsid

                var passTicket:array[1,string]
                discard loginBody.match(re".*<pass_ticket>(.*?)</pass_ticket>.*", passTicket)
                loginInfo["passTicket"] = if passTicket.len != 0 : %passTicket[0] else: %""
                var syncUrl = redirectUrl.substr(0, redirectUrl.rfind("/")-1)
                loginInfo{"syncUrl"} = %syncUrl
                loginInfo{"fileUrl"} = %syncUrl
                loginInfo{"url"} = %syncUrl
                echo "syncUrl:",syncUrl
                isLoggedIn = true
            
                webInit()
            sleep(1000)

        syncCheck()


proc main =
    if r =~ re """window.QRLogin.code = (\d+); window.QRLogin.uuid = "(\S+?)";""":
        echo matches
        var uuid = matches[1]
        var task = TaskPool.new()
        task.spawn checkLogin(uuid)
        var qrcode = &"{baseUrl}/l/" & uuid
        echo "qrcode:",qrcode
        let myQR = newQR(qrcode)
        myQR.printTerminal
main()

var running = true
proc controlCHandler() {.noconv.} =
  echo "\nCtrl+C pressed. Waiting for a graceful shutdown."
  running = false
setControlCHook(controlCHandler)

while running:
    sleep(1000)
