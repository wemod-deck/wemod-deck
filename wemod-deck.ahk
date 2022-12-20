#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#SingleInstance force
#NoTrayIcon
#Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

#Include libs\JSON.ahk

WEMOD_DECK_URL := "https://github.com/wemod-deck/wemod-deck"
WEMOD_DECK_VERSION := "1.1"

WEMOD_CATALOG := {}
PLATFORM_LABELS := ["Steam", "Xbox", "GOG", "Epic"]
PLATFORM_IDS := ["steam", "uwp", "gog", "epic"]


ReadAccessToken()
{
    FileRead, Token, %A_WorkingDir%\token.txt
    JsonToken := JSON.Load(Token)
    return JsonToken
}


DoLogin(GrantType, UserEmail, UserPassword)
{
    Url := "https://api.wemod.com/auth/token"
    If (GrantType = "password")
    {
        Data := "client_id=infinity&gdpr_consent_given=0&grant_type=password&password=" UserPassword "&username=" UserEmail
    }
    Else
    {
        Data := "client_id=infinity&gdpr_consent_given=0&grant_type=refresh_token&refresh_token=" UserEmail
    }

    oHTTP := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    oHTTP.Open("POST", Url, true)

    oHTTP.SetRequestHeader("accept", "*/*")
    oHTTP.SetRequestHeader("accept-language", "en-US")
    oHTTP.SetRequestHeader("content-type", "application/x-www-form-urlencoded")
    oHTTP.SetRequestHeader("sec-ch-ua", """ Not A;Brand"";v=""99"", ""Chromium"";v=""102""")
    oHTTP.SetRequestHeader("sec-ch-ua-mobile", "?0")
    oHTTP.SetRequestHeader("sec-ch-ua-platform", """Windows""")
    oHTTP.SetRequestHeader("sec-fetch-dest", "empty")
    oHTTP.SetRequestHeader("sec-fetch-mode", "cors")
    oHTTP.SetRequestHeader("sec-fetch-site", "cross-site")
    oHTTP.SetRequestHeader("user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) WeMod/8.3.10 Chrome/102.0.5005.167 Electron/19.1.3 Safari/537.36")

    If (GrantType = "refresh_token")
    {
        oHTTP.SetRequestHeader("authorization", "Bearer " UserPassword)
    }

    oHTTP.Send(Data)
    oHTTP.WaitForResponse()

    Response := oHTTP.ResponseText
    JsonResponse := JSON.Load(Response)
    If (JsonResponse.access_token != "")
    {
        FileDelete, %A_WorkingDir%\token.txt
        FileAppend, %Response%, %A_WorkingDir%\token.txt
        Return True    
    }

    Return False
}


Gui, 1: New, , WeMod Deck %WEMOD_DECK_VERSION%
Gui, 1: Font, s12
Gui, 1: Add, Text, , Logging in && downloading database...

Gui, 2: New, , WeMod Deck %WEMOD_DECK_VERSION%
Gui, 2: Font, s12
Gui, 2: Add, Text, , Please log in with your WeMod account first.
Gui, 2: Add, Text, , Email:
Gui, 2: Add, Edit, w300 vUserEmail
Gui, 2: Add, Text, , Password:
Gui, 2: Add, Edit, Password w300 vUserPassword
Gui, 2: Add, Button, Default w100 gButtonLogin vBtnLogin, Log in

Gui, 3: New, , WeMod Deck %WEMOD_DECK_VERSION%
Gui, 3: Font, s12
Gui, 3: Add, Text, , WeMod Game URL:
Gui, 3: Add, Edit, vGameUrl w500
Gui, 3: Add, Text, , Platform:
Gui, 3: Add, DropDownList, AltSubmit Choose1 vGamePlatform, % JoinString(PLATFORM_LABELS, "|", True)
Gui, 3: Add, Button, Default gButtonGenerate vBtnGenerate, Generate Trainer
Gui, 3: Add, Button, gButtonClear x+10, Clear
Gui, 3: Font, s10
Gui, 3: Add, Link, x+10, <a href="https://www.wemod.com/cheats?sort=latest">Game List</a>

Gui, 1: Show, w350 Center


AccessToken := ReadAccessToken()
If (AccessToken.access_token = "")
{
    Gui, 2: Show
    Gui, 1: Hide
    Gui, 3: Hide
}
Else
{
    Status := DoLogin("refresh_token", AccessToken.refresh_token, AccessToken.access_token)
    If (Status)
    {
		Global WEMOD_CATALOG
	    UrlDownloadToFile, https://storage-cdn.wemod.com/catalog.json, %A_WorkingDir%\catalog.json
		FileRead, Catalog, %A_WorkingDir%\catalog.json
		WEMOD_CATALOG := JSON.Load(Catalog)
		
        Gui, 3: Show
        Gui, 1: Hide
        Gui, 2: Hide
    }
    Else
    {
        Gui, 2: Show
        Gui, 1: Hide
        Gui, 3: Hide
    }
}

Return


ButtonLogin:
{
    Gui, Submit, NoHide

    GuiControl, Disable, UserEmail
    GuiControl, Disable, UserPassword
    GuiControl, Disable, BtnLogin

    Status := DoLogin("password", UserEmail, UserPassword)
    If (Status = False)
    {
        MsgBox, % "Invalid email/password. Please try again."
    }
    Else
    {
        Gui, 3: Show
        Gui, 1: Hide
        Gui, 2: Hide
    }

    GuiControl, Enable, UserEmail
    GuiControl, Enable, UserPassword
    GuiControl, Enable, BtnLogin
    Return
}


RemoveTrailingZero(num)
{
    Str := "" num
    Str := RegExReplace(Str, "(\d+(?=\.|,)[^0]+)(0+$)", "$1")
    Str := RTrim(Str, ".,")
    Return Str
}


JoinString(Arr, Char, RemoveTrailing:=False)
{
    Str := ""
    For Index, Value In Arr
    {
        Str := Str Value Char
    }

    If (RemoveTrailing)
    {
        Str := SubStr(Str, 1, -1 * StrLen(Char))
    }

    return Str
}


EscapeString(Str)
{
    Str := StrReplace(Str, "%", "``%")
    Return Str
}


GetGameInfo(URL, PlatformId)
{
	Global WEMOD_CATALOG

    oHTTP := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    oHTTP.Open("GET", URL , False)
    oHTTP.Send()
    oHTTP.WaitForResponse()

	RegExMatch(oHTTP.ResponseText, "title_id=(\d+)", TitleId)
	TitleInfo := WEMOD_CATALOG["titles"][TitleId1]
	GameId := 0
	For Index, Value in TitleInfo["gameIds"]
	{
		TmpGameInfo := WEMOD_CATALOG["games"][Value]
		If (TmpGameInfo["platformId"] = PlatformId)
		{
			GameId := Value
			Break
		}
	}

    Return {TitleId: TitleInfo["id"], GameId: GameId, Name: TitleInfo["name"], Slug: TitleInfo["slug"]}
}


GetAccessToken()
{
    FileRead, Token, %A_WorkingDir%\token.txt
    Return Token
}


GetTrainerData(GameInfo, AccessToken)
{
    URL := "https://api.wemod.com/v3/games/" GameInfo.GameId "/trainer?gameVersions=&locale=en-US&v=2"

    oHTTP := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    oHTTP.Open("GET", URL , False)
    oHTTP.SetRequestHeader("authorization", "Bearer " AccessToken.access_token)
    oHTTP.SetRequestHeader("user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) WeMod/8.3.10 Chrome/102.0.5005.167 Electron/19.1.3 Safari/537.36")
    oHTTP.Send()
    oHTTP.WaitForResponse()

    Response := JSON.Load(oHTTP.ResponseText)
    Return Response.trainer
}


HotkeysToString(Keys, Times)
{
    #Include libs\wemod-hotkeys.ahk

    KeyStr := ""
    For Index, Value In Keys
    {
        Switch Value
        {
            Case 16:  ; Shift
                KeyStr := KeyStr "+"
            Case 17:  ; Ctrl
                KeyStr := KeyStr "^"
            Case 18:  ; Alt
                KeyStr := KeyStr "!"
            Default:
                KeyStr := KeyStr "{" HOTKEYS[Value] " " Times "}"
                
        }
    }

    Return KeyStr
}


GenerateHotkeyGosub(Name, Keys, Times)
{
    KeyStr := HotkeysToString(Keys, Times)

    Script := []
    Script.Push(Name ":")
    Script.Push("{")
    Script.Push("Send, " KeyStr)
    Script.Push("Return")
    Script.Push("}")

    Return JoinString(Script, "`n")
}


GenerateHotkeySelectGosub(Name, Uuid, Keys)
{
    KeyStr := HotkeysToString(Keys, 1)
    KeyStr := StrReplace(KeyStr, "1}", "`%Times`%}")

    Script := []
    Script.Push(Name ":")
    Script.Push("{")
    Script.Push("Gui, Submit, NoHide")
    Script.Push("Times := [1, 5, 10, 20, 50][Select_" Uuid "]")
    Script.Push("Send, " KeyStr)
    Script.Push("Return")
    Script.Push("}")

    Return JoinString(Script, "`n")
}


GenerateTrainerScript(GameInfo, PlatformName, Trainer)
{
    Cheats := Trainer.blueprint.cheats

    Tabs := {}
    TabsArr := []
    CurrentCategory := ""
    For Index, Cheat In Cheats
    {
        If (!Tabs[Cheat.category])
        {
            CurrentCategory := Cheat.category
            StringUpper, TabName, CurrentCategory, T
            TabsArr.Push(TabName)
            Tabs[Cheat.category] := 1
        }
    }

    GuiScript := []
    GuiScript.Push("Gui, Add, Tab3, xs, " JoinString(TabsArr, "|", RemoveTrailing:=True))

    GoSubScript := ""
    CurrentCategory := ""
    XsValue := ""

    For TabIndex, TabName In TabsArr
    {
        XsValue := ""
        GuiScript.Push("Gui, Tab, " TabIndex)

        For CheatIndex, Cheat In Cheats
        {
            StringUpper, CurrentCategory, % Cheat.category, T
            If (CurrentCategory != TabName)
            {
                Continue
            }

            Uuid := Cheat.Uuid

            GuiScript.Push("Gui, Add, Text, Section w300 h30 y+16 " XsValue ", " EscapeString(Cheat.name))
            XsValue := "xs"


            If (Cheat.type = "toggle")
            {
                GoSubName := "Toggle_" Uuid
                GuiScript.Push("Gui, Add, Button, x+10 w100 h40 g" GoSubName ", Toggle")

                GoSubScript := GoSubScript GenerateHotkeyGosub(GoSubName, Cheat.hotkeys[1], 1)
            }
            Else If (Cheat.type = "button")
            {
                GoSubName := "Button_" Uuid
                GuiScript.Push("Gui, Add, Button, x+10 w100 h40 g" GoSubName ", Activate")

                GoSubScript := GoSubScript GenerateHotkeyGosub(GoSubName, Cheat.hotkeys[1], 1)
            }
            Else If (Cheat.type = "number" Or Cheat.type = "slider")
            {
                StepTimes := [1, 5, 10, 20, 50]
                Steps := []
                For Index, Value In StepTimes
                {
                    Steps.Push("" RemoveTrailingZero(Cheat.args.step * Value))
                }

                GuiScript.Push("Gui, Add, Button, x+10 w50 h40 gDec_" Uuid ", -")
                GuiScript.Push("Gui, Add, DropDownList, AltSubmit Choose1 x+10 w150 vSelect_" Uuid ", " JoinString(Steps, "|", RemoveTrailing:=True))
                GuiScript.Push("Gui, Add, Button, x+10 w50 h40 gInc_" Uuid ", +")
                GuiScript.Push("Gui, Add, Button, x+10 h40 gMin_" Uuid ", Min: " Cheat.args.min)
                GuiScript.Push("Gui, Add, Button, x+10 h40 gMax_" Uuid ", Max: " Cheat.args.max)

                MaxSteps := Ceil((Cheat.args.max - Cheat.args.min) / Cheat.args.step)
                GoSubScript := GoSubScript GenerateHotkeyGosub("Min_" Uuid, Cheat.hotkeys[1], MaxSteps)
                GoSubScript := GoSubScript GenerateHotkeyGosub("Max_" Uuid, Cheat.hotkeys[2], MaxSteps)

                GoSubScript := GoSubScript GenerateHotkeySelectGosub("Dec_" Uuid, Uuid, Cheat.hotkeys[1])
                GoSubScript := GoSubScript GenerateHotkeySelectGosub("Inc_" Uuid, Uuid, Cheat.hotkeys[2])
            }
        }
    }

    GuiScript.Push("Gui, Show, AutoSize Center")
    GuiScript.Push("Return")    

    Global WEMOD_DECK_URL
    Global WEMOD_DECK_VERSION
    GameName := EscapeString(GameInfo.Name)
    ReleasedAt := Trainer.releasedAt
    FullScript =
(
`; Generated by WeMod Deck %WEMOD_DECK_VERSION%
`; %WEMOD_DECK_URL%
#NoEnv
#SingleInstance force
#NoTrayIcon
SendMode Input
SetWorkingDir `%A_ScriptDir`%

Gui, New, , [%PlatformName%] %GameName%
Gui, Font, s8
Gui, Add, StatusBar, , WeMod trainer version: %ReleasedAt% // Generated by WeMod Deck %WEMOD_DECK_VERSION%
Gui, Font, s12
Gui, Add, Button, Section gRunGame, Run Game with WeMod
Gui, Add, Button, gRunSwicd x+10, Run SWICD
Gui, Add, Button, gCloseSwicd x+10, Close SWICD
)
    FullScript := FullScript "`n" JoinString(GuiScript, "`n") GoSubScript

    FunctionButtonsScript := ["RunGame:"
        , "{"
        , "Run, wemod://play?titleId=" Trainer.titleId "&gameId=" Trainer.gameId
        , "Return"
        , "}"
        , "RunSwicd:"
        , "{"
        , "Try"
        , "Run, `%A_ProgramFiles`%\Maximilian Kenfenheuer\SWICD\SWICD.exe"
        , "Catch e"
        , "MsgBox, SWICD is not installed!"
        , "Return"
        , "}"
        , "CloseSwicd:"
        , "{"
        , "Process, Close, SWICD.exe"
        , "Return"
        , "}"]
    FullScript := FullScript JoinString(FunctionButtonsScript, "`n")
	
	StringLower, PlatformName, PlatformName
	FileLocation := "\trainers\" GameInfo.Slug "-" PlatformName "-trainer.ahk"
    
    FileCreateDir, % A_WorkingDir "\trainers\"
    FileDelete, % A_WorkingDir FileLocation
    FileAppend, %FullScript%, % A_WorkingDir FileLocation
	
	MsgBox, % "Saved to: " FileLocation
    Return True
}


ButtonGenerate:
{
    Gui, Submit, NoHide

    GuiControl, Disable, GameUrl
    GuiControl, Disable, BtnGenerate

    If (GameUrl = "" Or !InStr(GameUrl, "wemod.com/cheats/"))
    {
        MsgBox, Invalid Game URL
    }
    Else
    {
		PlatformId := PLATFORM_IDS[GamePlatform]
		PlatformName := PLATFORM_LABELS[GamePlatform]
	
        AccessToken := ReadAccessToken()
        GameInfo := GetGameInfo(GameUrl, PlatformId)
		
		If (GameInfo.GameId = 0)
		{
			MsgBox, ERROR: No trainer for this platform!
		}
		Else
		{
			Trainer := GetTrainerData(GameInfo, AccessToken)
			GenerateTrainerScript(GameInfo, PlatformName, Trainer)
		}
    }

    GuiControl, Enable, GameUrl
    GuiControl, Enable, BtnGenerate

    Return
}


ButtonClear:
{
    Gui, Submit, NoHide

    GuiControl, Text, GameUrl, 
    Return
}
