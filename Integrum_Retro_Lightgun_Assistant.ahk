#SingleInstance force
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn


SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
Global Debug := 0
Global Version := 2.0

; Configuration files

Global GUNP1_POS		:= "" ; Player 1 GUN ID Position
Global GUNP2_POS		:= "" ; Player 2 GUN ID Position
Global GUNP3_POS		:= "" ; Player 3 GUN ID Position
Global GUNP4_POS		:= "" ; Player 4 GUN ID Position
Global GUNP1_TYPE 		:= "" ; Brand Name ex. Sinden Lightgun Black
Global GUNP2_TYPE 		:= "" ; Brand Name ex. Arduino LLC GUN4IR Pro Micro P1
Global GUNP3_TYPE		:= ""
Global GUNP4_TYPE		:= ""
Global GUNP1_HID 		:= ; Player 1 Lightgun full HID
Global GUNP2_HID 		:= ; Player 2 Lightgun full HID
Global GUNP3_HID		:= ; Player 3 Lightgun full HID
Global GUNP4_HID		:= ; Player 4 Lightgun full HID
Global GUNS 			:= 0 ; total number of guns detected


For index, arg in A_Args {
    If (arg = "debug") {
        FileDelete, %A_ScriptDir%\Integrum_Retro_debug.log
        Debug := 1
    }
}

Main(A_Args)
ExitApp

Main(Args) {
    SystemParameter1 := Args[1]
    SystemParameter2 := Args[2]
    SystemParameter3 := Args[3]
    SystemParameter4 := Args[4]


    If (!SystemParameter1 || SystemParameter1 = "version") {
        MsgBox, Integrum Retro Lightgun Assistant v%version% by Jasen Baker (jasen@integrumretro.com)
        ExitApp
    }

	If (SystemParameter1 = "help")
	{
		MsgBox, 64, Help Menu, 
		(
Integrum Retro Lightgun Assistant v%version% by Jasen Baker (jasen@integrumretro.com)

Available Commands:

lightgun start   - Start Sinden lightgun software.
lightgun stop   - Stop Sinden lightgun software.
lightgun list   - List detected lightguns.
lightgun demulshooter   - Configure DemulShooter.
lightgun mame   - Configure for MAME.
lightgun teknoparrot <game>   - Configure Teknoparrot for specified game.
version   - Display the current version.
help   - Show this help menu.
		)
		ExitApp
	}

    Switch SystemParameter1 {
        Case "lightgun":
            FindLightguns()

            Switch SystemParameter2 {
                Case "start":
                    StopDemulShooter()
                    StartSindenSoftware()
                    ExitApp

                Case "stop":
                    StopSindenSoftware()
                    StopDemulShooter()
                    ExitApp

                Case "list":
                    Debug := 1
                    FindLightguns()
                    Return

                Case "demulshooter":
                    LogDebug("INFO", "Configuring demulshooter...")
                    CreateDemulShooterConfig()
                    Return

                Case "mame":
                    LogDebug("INFO", "Configuring MAME...")
                    CreateMAMEConfig()
                    Return

                Case "teknoparrot":
                    LogDebug("INFO", "Configuring Teknoparrot...")
                    CreateTeknoparrotConfig(SystemParameter3)
                    CreateDemulshooterConfig()
                    Return

                Default:
                    LogDebug("WARN", "Unknown lightgun command: " SystemParameter2)
                    Return
            }

            ; Show a GUI message if no guns are detected, doesn't create a forced input box that breaks BigBox
            If (GUNS = 0) {
                Gui, +AlwaysOnTop +ToolWindow -Caption
                Gui, Font, s20  ; Set font size to 20pt
                Gui, Add, Text, w600 h200, No lightguns detected!`n`nThis is a lightgun-only game.`nPlease plug in your lightguns and try again.`n`nThis message will self-destruct in 5 seconds.
                Gui, Show, Center  ; Center the GUI window on the screen
                Sleep 7000
                ExitApp
            }
            Return

        Default:
            LogDebug("WARN", "Unknown command: " SystemParameter1)
            Return
    }
    ExitApp
}

FindLightguns()
{
    SizeofRawInputDeviceList := A_PtrSize * 2
    SizeofRawInputDevice := 8 + A_PtrSize
    RIM_TYPEMOUSE := 0
    RIDI_DEVICENAME := 0x20000007

    mouse := 1 ; Counts how many mouse devices found
    Res := DllCall("GetRawInputDeviceList", "Ptr", 0, "UInt*", Count, UInt, SizeofRawInputDeviceList)
    VarSetCapacity(RawInputList, SizeofRawInputDeviceList * Count)
    Res := DllCall("GetRawInputDeviceList", "Ptr", &RawInputList, "UInt*", Count, "UInt", SizeofRawInputDeviceList)

    LogDebug("DEBUG", "Device IDs found in Enumerated Order")
    LogDebug("DEBUG", "------------------------------------")

    Loop %Count%
    {
        Handle := NumGet(RawInputList, (A_Index - 1) * SizeofRawInputDeviceList, "UInt")
        Type := NumGet(RawInputList, ((A_Index - 1) * SizeofRawInputDeviceList) + A_PtrSize, "UInt")

        ; Process only RIM_TYPEMOUSE devices
        If (Type = RIM_TYPEMOUSE)
        {
            Res := DllCall("GetRawInputDeviceInfo", "Ptr", Handle, "UInt", RIDI_DEVICENAME, "Ptr", 0, "UInt *", nLength)
            VarSetCapacity(Name, (nLength + 1) * 2)
            Res := DllCall("GetRawInputDeviceInfo", "Ptr", Handle, "UInt", RIDI_DEVICENAME, "Str", Name, "UInt*", nLength)
            LogDebug("DEBUG", "Mouse/Lightgun " . Name)

            ; Read lightgun definitions from INI
            If FileExist("IntegrumRetro.ini")
                IniRead, DeviceID, IntegrumRetro.ini, LIGHTGUNS
            Else
            {
                MsgBox, FATAL: IntegrumRetro.ini not found, cannot obtain lightgun list
                ExitApp
            }

            ; Match device with INI definitions
            Loop, parse, DeviceID, `n
            {
                parts := StrSplit(A_LoopField, "=")
                DeviceHidVid := parts[1]
                DeviceDescription := parts[2]

                If Instr(Name, DeviceHidVid)
                {
                    GUNS += 1
					GUNP%mouse%_POS := mouse
                    GUNP%mouse%_HID := Name
                    GUNP%mouse%_TYPE := DeviceDescription
                    mouse += 1
                }
            }
        }
    }

    ; Log the assigned lightguns
    LogDebug("DEBUG", "Lightgun Player 1 index: " . GUNP1_POS . " type: " . GUNP1_TYPE . " name: " . GUNP1_HID)
    LogDebug("DEBUG", "Lightgun Player 2 index: " . GUNP2_POS . " type: " . GUNP2_TYPE . " name: " . GUNP2_HID)
    LogDebug("DEBUG", "Lightgun Player 3 index: " . GUNP3_POS . " type: " . GUNP3_TYPE . " name: " . GUNP3_HID)
    LogDebug("DEBUG", "Lightgun Player 4 index: " . GUNP4_POS . " type: " . GUNP4_TYPE . " name: " . GUNP4_HID)
    LogDebug("DEBUG", "Total Guns: " . (mouse - 1))
    Return
}




CreateMAMEConfig()
{
    ; Read MAME controller template file path from IntegrumRetro.ini
    IniRead, MAME_CTRLR_TEMPLATE, IntegrumRetro.ini, MAME, MAME_CTRLR_TEMPLATE
	IniRead, MAME_CTRLR_CFG, IntegrumRetro.ini, MAME, MAME_CTRLR_CFG

    ; Apply the "&" to "&amp;" transformation to GUN HIDs
    P1_GUN_HID := StrReplace(GUNP1_HID, "&", "&amp;")
    P2_GUN_HID := StrReplace(GUNP2_HID, "&", "&amp;")
    P3_GUN_HID := StrReplace(GUNP3_HID, "&", "&amp;")
    
    If FileExist(MAME_CTRLR_TEMPLATE)
    {
        FileRead, Content, %MAME_CTRLR_TEMPLATE%

        ; Replace placeholders with transformed GUN HIDs
        newContent := StrReplace(Content, "###LIGHTGUN1###", P1_GUN_HID)
        newContent := StrReplace(newContent, "###LIGHTGUN2###", P2_GUN_HID)
        newContent := StrReplace(newContent, "###LIGHTGUN3###", P3_GUN_HID)

        ; Write the new configuration to MAME controller config file
        FileDelete, %MAME_CTRLR_CFG%
        FileAppend, %newContent%, %MAME_CTRLR_CFG%

        LogDebug("INFO", "Successfully created MAME controller config file at " . MAME_CTRLR_CFG)

        ; Determine which type of guns are detected and create corresponding MAME artwork
        If InStr(GUNP1_TYPE, "Sinden") or InStr(GUNP2_TYPE, "Sinden") or InStr(GUNP3_TYPE, "Sinden")
		{
            CreateMameArtwork("Sinden")
		}
		
        Else
		{
            CreateMameArtwork("Other")
		}
    }

    Else
    {

        LogDebug("ERROR", "MAME Controller Template File missing, this must be replaced for automation to work.")
    }
}

CreateMameArtwork(ByRef GunType)
{
    ; Read variables from IntegrumRetro.ini in the mame section
    IniRead, ArtworkFolder, IntegrumRetro.ini, MAME, ArtworkFolder
    IniRead, ArtworkFolderOther, IntegrumRetro.ini, MAME, ArtworkFolderOther
    IniRead, ArtworkFolderSinden, IntegrumRetro.ini, MAME, ArtworkFolderSinden

    LogDebug("DEBUG", "ArtworkFolder: " . ArtworkFolder)
    LogDebug("DEBUG", "ArtworkFolderOther: " . ArtworkFolderOther)
    LogDebug("DEBUG", "ArtworkFolderSinden: " . ArtworkFolderSinden)

    If (GunType = "Sinden")
    {
        LogDebug("INFO", "GunType is Sinden")
        
		If !FileExist(ArtworkFolder)
        {
            LogDebug("INFO", "ArtworkFolder does not exist. Moving ArtworkFolderSinden to ArtworkFolder")
            FileMoveDir, %ArtworkFolderSinden%, %ArtworkFolder%, R
        }
        
		Else If FileExist(ArtworkFolderSinden)
        {
            LogDebug("INFO", "ArtworkFolder and ArtworkFolderSinden both exist. Moving ArtworkFolder to ArtworkFolderOther and ArtworkFolderSinden to ArtworkFolder")
            FileMoveDir, %ArtworkFolder%, %ArtworkFolderOther%, R
            FileMoveDir, %ArtworkFolderSinden%, %ArtworkFolder%, R
        }
    }
	
    Else If (GunType = "Other")
    {
        LogDebug("INFO", "GunType is Other")
        
		If !FileExist(ArtworkFolder)
        {
            LogDebug("INFO", "ArtworkFolder does not exist. Moving ArtworkFolderOther to ArtworkFolder")
            FileMoveDir, %ArtworkFolderOther%, %ArtworkFolder%, R
        }
        
		Else If FileExist(ArtworkFolderOther)
        {
            LogDebug("INFO", "ArtworkFolder and ArtworkFolderOther both exist. Moving ArtworkFolder to ArtworkFolderSinden and ArtworkFolderOther to ArtworkFolder")
            FileMoveDir, %ArtworkFolder%, %ArtworkFolderSinden%, R
            FileMoveDir, %ArtworkFolderOther%, %ArtworkFolder%, R
        }
    }
	
Return
}

CreateDemulshooterConfig()
{
    IniRead, DEMULSHOOTER_CFG_TEMPLATE, IntegrumRetro.ini, DEMULSHOOTER, DEMULSHOOTER_CFG_TEMPLATE, NOT_FOUND
    IniRead, DEMULSHOOTER_CFG, IntegrumRetro.ini, DEMULSHOOTER, DEMULSHOOTER_CFG, NOT_FOUND

    If !FileExist(DEMULSHOOTER_CFG_TEMPLATE)
    {
        LogDebug("ERROR", "Demulshooter configuration template file not found at " . DEMULSHOOTER_CFG_TEMPLATE " This will break lightgun autodetection unless fixed")
        MsgBox, Demulshooter configuration template file not found at %DEMULSHOOTER_CFG_TEMPLATE%`n`n This will break lightgun autodetection unless fixed
        return
    }

    Try
    {
        FileRead, Content, %DEMULSHOOTER_CFG_TEMPLATE%

        ; Initialize newContent with the template content
        newContent := Content

        ; Replace light gun placeholders based on the number of guns configured (GUNS variable)
        Loop % GUNS
        {
            gun_var := "GUNP" . A_Index . "_HID"
            newContent := StrReplace(newContent, "###LIGHTGUN" . A_Index . "###", %gun_var%)
        }
        
        FileDelete, %DEMULSHOOTER_CFG% 
        FileAppend, %newContent%, %DEMULSHOOTER_CFG% 
        
        LogDebug("INFO", "Successfully created Demulshooter config file at " . DEMULSHOOTER_CFG)
    }
	
    catch exception
    {
        LogDebug("ERROR", "Error in CreateDemulshooterConfig: " . exception.message)
        MsgBox, Error occurred in creating Demulshooter config file.`nCheck debug logs for details.
    }
}

CopyReshadeFile(GunType, ReshadeDest)
{
    IniRead, RESHADE_SINDEN_INI, IntegrumRetro.ini, RESHADE, RESHADE_SINDEN_INI
	IniRead, RESHADE_OTHER_INI, IntegrumRetro.ini, RESHADE, RESHADE_OTHER_INI
	
    SINDEN := InStr(GunType, "Sinden") ? "true" : "false"

    SourceFile := SINDEN = "true" ? RESHADE_SINDEN_INI : RESHADE_OTHER_INI

    If !FileExist(SourceFile)
    {
        LogDebug("ERROR", "Reshade file not found: " . SourceFile)
    }
	
    If !FileExist(ReshadeDest)
    {
        LogDebug("ERROR", "Reshade Destination directory not found: " . ReshadeDest)
    }

    FileCopy, %SourceFile%, %ReshadeDest%, 1

    LogDebug("INFO", "Reshade file copied to " . ReshadeDest)
}

CreateTeknoparrotConfig(Game)
{

    ; Replace '&' with '&amp;' in HID variables to be compatible with Teknoparrot xml profiles
    TP_GUNP1_HID := StrReplace(GUNP1_HID, "&", "&amp;")
    TP_GUNP2_HID := StrReplace(GUNP2_HID, "&", "&amp;")
    TP_GUNP3_HID := StrReplace(GUNP3_HID, "&", "&amp;")
    TP_GUNP4_HID := StrReplace(GUNP4_HID, "&", "&amp;")

    ; Read reshade path based on the GAME variable
    IniRead, RESHADE_PATH, IntegrumRetro.ini, TEKNOPARROT, %GAME%_RESHADE
    
	If !(RESHADE_PATH = "ERROR") 
	{
		CopyReshadeFile(GUNP1_TYPE, RESHADE_PATH)
	}

	Else
	{
		If (%Game% != "")
		{
			LogDebug("ERROR", "Reshade path not found for the game: " . Game)
		}
    }

    IniRead, TP_USER_TEMPLATE_DIR, IntegrumRetro.ini, TEKNOPARROT, TP_USER_TEMPLATE_DIR
	
	LogDebug("INFO", "Teknoparrot Template DIR configured for " . TP_USER_TEMPLATE_DIR)
	
    If (TP_USER_TEMPLATE_DIR = "ERROR")
	{
		LogDebug("ERROR", "Teknoparrot TP_USER_TEMPLATE_DIR not found at section [TEKNOPARROT] in " . IntegrumRetro.ini)
    }

    If !FileExist(TP_USER_TEMPLATE_DIR)
    {
		LogDebug("ERROR", "Teknoparrot User TEMPLATE Profiles Directory not found at " . TP_USER_TEMPLATE_DIR)
    }

    IniRead, TP_USER_PROFILE_DIR, IntegrumRetro.ini, TEKNOPARROT, TP_USER_PROFILE_DIR
	
    If ("TP_USER_PROFILE_DIR" = "ERROR")
	{
		LogDebug("ERROR", "Teknoparrot TP_USER_PROFILE_DIR not found at section [TEKNOPARROT] in  " . IntegrumRetro.ini)
	}

    If !FileExist(TP_USER_PROFILE_DIR)
    {
		LogDebug("ERROR", "Teknoparrot User Profiles Directory not found at " . TP_USER_PROFILE_DIR)
    }

    LogDebug("INFO", "Rewriting Teknoparrot profiles..")
	; Iterate over user profile templates and create user profiles
	
	
	
    Loop, Files, %TP_USER_TEMPLATE_DIR%\*.xml
    {		
		ProfileTemplate := A_LoopFileLongPath
		FileName := A_LoopFileName
        
		IniRead, TP_GAME_ROOT_DIR, IntegrumRetro.ini, TEKNOPARROT_GAME_PATH, %FileName%

		If (ErrorLevel)
		{
			LogDebug("ERROR", "Failed to find folder path for " . FileName . " at " TP_GAME_ROOT_DIR)
		}
		
		UserProfile := TP_USER_PROFILE_DIR . "\" . A_LoopFileName
		
		
		LogDebug("DEBUG", "Rewriting Teknoparrot " . FileName)

		FileRead, Content, %TP_USER_TEMPLATE_DIR%\%FileName%
		
		newContent := StrReplace(Content, "###LIGHTGUN1###", TP_GUNP1_HID)

		; Replace placeholders in profile content
		newContent := StrReplace(newContent, "###TP_GAME_ROOT_DIR###", TP_GAME_ROOT_DIR)
		newContent := StrReplace(newContent, "###LIGHTGUN1###", TP_GUNP1_HID)
		newContent := StrReplace(newContent, "###LIGHTGUN1 NAME###", GUNP1_TYPE)
		newContent := StrReplace(newContent, "###LIGHTGUN1 LeftButton###", GUNP1_TYPE "LeftButton")
		newContent := StrReplace(newContent, "###LIGHTGUN1 RightButton###", GUNP1_TYPE "RightButton")
		newContent := StrReplace(newContent, "###LIGHTGUN1 MiddleButton###", GUNP1_TYPE "MiddleButton")
		newContent := StrReplace(newContent, "###LIGHTGUN2###", TP_GUNP2_HID)
		newContent := StrReplace(newContent, "###LIGHTGUN2 NAME###", GUNP2_TYPE)
		newContent := StrReplace(newContent, "###LIGHTGUN2 LeftButton###", GUNP2_TYPE "LeftButton")
		newContent := StrReplace(newContent, "###LIGHTGUN2 RightButton###", GUNP2_TYPE "RightButton")
		newContent := StrReplace(newContent, "###LIGHTGUN2 MiddleButton###", GUNP2_TYPE "MiddleButton")
		newContent := StrReplace(newContent, "###LIGHTGUN3###", TP_GUNP3_HID)
		newContent := StrReplace(newContent, "###LIGHTGUN3 NAME###", GUNP3_TYPE)
		newContent := StrReplace(newContent, "###LIGHTGUN3 LeftButton###", GUNP3_TYPE "LeftButton")
		newContent := StrReplace(newContent, "###LIGHTGUN3 RightButton###", GUNP3_TYPE "RightButton")
		newContent := StrReplace(newContent, "###LIGHTGUN3 MiddleButton###", GUNP3_TYPE "MiddleButton")
		newContent := StrReplace(newContent, "###LIGHTGUN4###", TP_GUNP4_HID)
		newContent := StrReplace(newContent, "###LIGHTGUN4 NAME###", GUNP4_TYPE)
		newContent := StrReplace(newContent, "###LIGHTGUN4 LeftButton###", GUNP4_TYPE "LeftButton")
		newContent := StrReplace(newContent, "###LIGHTGUN4 RightButton###", GUNP4_TYPE "RightButton")
		newContent := StrReplace(newContent, "###LIGHTGUN4 MiddleButton###", GUNP4_TYPE "MiddleButton")

		; Write modified content back to the profile file
		FileDelete, %UserProfile%
		FileAppend, %newContent%, %UserProfile%


		LogDebug("DEBUG", "Updated " . UserProfile)
    }
	
	LogDebug("INFO", "Teknoparrot Profiles Updated.. ")
	
Return
}

StartSindenSoftware()
{
	IniRead, SINDEN_LIGHTGUN_EXE, IntegrumRetro.ini, SINDEN, SINDEN_LIGHTGUN_EXE
	IniRead, SINDEN_CONFIG_FILE, IntegrumRetro.ini, SINDEN, SINDEN_CONFIG_FILE
	
	Process, Exist, Lightgun.exe
	If (ErrorLevel) ; ErrorLevel contains the PID if the process exists
	{
		LogDebug("INFO", "Sinden Software already running, attempting to terminate")
		StopSindenSoftware()
	}
	
	
	If !FileExist(SINDEN_LIGHTGUN_EXE)
	{
		LogDebug("ERROR","Sinden Lightgun.exe not found at [" . SINDEN_LIGHTGUN_EXE . "] please fix the location entry in the IntegrumRetro.ini file")
		ExitApp
	}
	
	If InStr(GUNP1_TYPE, "Sinden")
	{		
		If !FileExist(SINDEN_CONFIG_FILE)
		{
			LogDebug("ERROR", SINDEN_CONFIG_FILE . " is missing, please update integrumretro.ini so the Sinden software can be properly configured")
			ExitApp
		}
		
		SINDEN_BACKUP_FILE := SINDEN_CONFIG_FILE . ".backup"
		
		FileCopy, %SINDEN_CONFIG_FILE%, %SINDEN_BACKUP_FILE%, 1
		FileRead, xmldata, %SINDEN_CONFIG_FILE%
		FileDelete, %SINDEN_CONFIG_FILE%

		xmldata	:= RegExReplace(xmldata,".*cbButtonTrigger"".*", "    <add key=""cbButtonTrigger"" value=""1"" />")
		xmldata	:= RegExReplace(xmldata,".*cbButtonTriggerB"".*", "    <add key=""cbButtonTriggerB"" value=""1"" />")

		xmldata	:= RegExReplace(xmldata,".*cbButtonTriggerOffscreen"".*", "    <add key=""cbButtonTriggerOffscreen"" value=""3"" />")
		xmldata	:= RegExReplace(xmldata,".*cbButtonTriggerOffscreenB"".*", "    <add key=""cbButtonTriggerOffscreenB"" value=""3"" />")
		
		xmldata	:= RegExReplace(xmldata,".*cbButtonFrontRight"".*", "    <add key=""cbButtonFrontRight"" value=""9"" />")
		xmldata := RegExReplace(xmldata,".*cbButtonFrontRightB"".*", "    <add key=""cbButtonFrontRightB"" value=""10"" />")
		
		xmldata := RegExReplace(xmldata,".*cbButtonFrontRightOffscreen"".*", "    <add key=""cbButtonFrontRightOffscreen"" value=""13"" />")
		xmldata := RegExReplace(xmldata,".*cbButtonFrontRightOffscreenB"".*", "    <add key=""cbButtonFrontRightOffscreenB"" value=""14"" />")
		
		xmldata	:= RegExReplace(xmldata,".*cbButtonFrontLeftOffscreen"".*", "    <add key=""cbButtonFrontLeftOffscreen"" value=""3"" />")
		xmldata	:= RegExReplace(xmldata,".*cbButtonFrontLeftOffscreenB"".*", "    <add key=""cbButtonFrontLeftOffscreenB"" value=""3"" />")

		xmldata	:= RegExReplace(xmldata,".*cbButtonPumpActionOffscreen"".*", "    <add key=""cbButtonPumpActionOffscreen"" value=""3"" />")
		xmldata	:= RegExReplace(xmldata,".*cbButtonPumpActionOffscreenB"".*", "    <add key=""cbButtonPumpActionOffscreenB"" value=""3"" />")
		
		xmldata := RegExReplace(xmldata,".*chkRecoilTrigger"".*", "    <add key=""chkRecoilTrigger"" value=""1"" />")
		xmldata	:= RegExReplace(xmldata,".*chkAutoStart"".*", "    <add key=""chkAutoStart"" value=""1"" />")
		
		xmldata	:= RegExReplace(xmldata,".*chkStartInTray"".*", "    <add key=""chkStartInTray"" value= ""1"" />")
		FileAppend, %xmldata%, %SINDEN_CONFIG_FILE%
		
		Run, %SINDEN_LIGHTGUN_EXE%,, Hide
		
		; We want to give enough time for the Sinden software to start before we proceed
		sleep 4000

		Process, Exist, Lightgun.exe
		If (ErrorLevel)
		{
			LogDebug("INFO", "Sinden Software successfully started")
			Return
		}
		
		Else
		{
			LogDebug("ERROR", "Sinden software failed to start")
			ExitApp
		}
		
		Return
	}
	
Return	
}

StopDemulshooter()
{
	Process, Close, demulshooter.exe
	Process, Close, demulshooterx64.exe
	Return
}

StopSindenSoftware()
{
    Process, Exist, Lightgun.exe
    If (ErrorLevel) 
    {
        Process, Close, Lightgun.exe
		Run, taskkill /im "Lightgun.exe" /F,, Hide
        Sleep 2000
        
        LogDebug("INFO", "Sinden Software terminated")
    }

    Return
}


LogDebug(level, message)
{
    FormatTime, timestamp, A_Now, yyyy/MM/dd HH:mm:ss


    If (Debug = 1)
    {
        logMessage := timestamp . " " . level . "  : " . message . "`n"
        FileAppend, %logMessage%, %A_ScriptDir%\Integrum_Retro_debug.log
    }

    Else If (Debug = 0)
    {
        ; Log all messages except DEBUG level
        If (level != "DEBUG")
        {
            logMessage := timestamp . " " . level . "  : " . message . "`n"
            FileAppend, %logMessage%, %A_ScriptDir%\Integrum_Retro_debug.log
        }
    }

    Sleep 10
}

ExitApp