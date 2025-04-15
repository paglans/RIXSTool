#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "json_functions"
#include "CreateItem" 
#include "zap"

Function RIXSTool()
	CreateRIXSToolsVariables()
	if(stringmatch(WinList("*",";","WIN:64"),"NeXusConverterPanel")==1)
		DoWindow/F NeXusConverterPanel
	else
		NeXusConverter()
	endif
End

Function CreateRIXSToolsVariables()
	String original = "root:Original"
	String treated = "root:Treated"
	if(!DataFolderExists(original))
		NewDataFolder $original
	endif
	if(!DataFolderExists(treated))
		NewDataFolder $treated
	endif
//	String common="root:Common"
//	if(!DataFolderExists(common)
//		NewDataFolder $common
//	endif
//	String/G/N=nexus $(common+":nexus")
//	nexus="NexusConverter"
	String basefolder="root:NeXusConverter"
	if(!DataFolderExists(basefolder))
		NewDataFolder $basefolder
	endif
	SVAR/Z impath=$(basefolder+":impath")
	if(!SVAR_exists(impath))
		String/G $(basefolder+":impath")
		SVAR impath=$(basefolder+":impath")
	endif
End

Function load_file(filename)
	String filename
	String basefolder=GetUserData("","","basefolder")
	String wname=GetUserData("","","windowname")
	String original=GetUserData("","","original")
	String treated=GetUserData("","","treated")
	SVAR impath=$(basefolder+":impath")
	DFREF saveDF = GetDataFolderDFR()
	SetDataFolder $original
	String fname = ReplaceString(" ",filename,"_")
	NewDataFolder/O/S $fname
	Variable refnum
	String contents, path
	path=impath+filename+".txt"
	Open/R/Z refNum as path
	if(V_flag)
		return 11
	endif
	
	FStatus refNum
	contents = PadString("",V_LogEOF, 0)
	FBinRead refnum, contents
	Close refNum
	String/G header_json, data
	SVAR header_json
	SVAR data
	Variable pos, counter
	pos = strsearch(contents, "DATA", 0)
	header_json = contents[0,pos-2]
	header_json = ReplaceString("HEADER", header_json, "")
	// JSON
	NewDataFolder/S Header
	Variable jsonid, tst
	Make/T/FREE toplevelkeys
	jsonid = JSON_Parse(header_json)
	JSONXOP_GetKeys jsonid,"",toplevelkeys
	Variable nkeys=numpnts(toplevelkeys)
	counter=0
	String jsonpath
	do
		jsonpath="/"+toplevelkeys[counter]
		Switch (JSON_GetType(jsonid,jsonpath))
			case 0:	//Object
				NewDataFolder/S $(RemoveBadCharacters(toplevelkeys[counter]))
				tst = CreateItem(header_json,jsonpath)
				SetDataFolder ::
				break
			case 1:	//Array
				Variable k=0,arraysize = JSON_GetArraySize(jsonid,jsonpath)
				String str
				Make/T/N=(arraysize) twave
				if (arraysize>0)
					do
       				sprintf str, "%s/%d", jsonpath,k
       				if(JSON_GetType(jsonId,str)==0)
       					print "tjo"
       					NewDataFolder/S $(RemoveBadCharacters(str))
       					CreateItem(header_json,str)
       					SetDataFolder ::
       				else
       					JSONXOP_GetValue/T jsonId, str
//						sprintf str, "%s/%d", jsonpath,k
//						JSONXOP_GetValue/WAVE=twave jsonId, str
       					twave[k]=S_Value
       				endif
   					k += 1
					while (k < arraysize)
	 			endif
				Rename twave,$(RemoveBadCharacters(toplevelkeys[counter]))
				break
			case 2:	//Variable
				Variable/G vtmp
				vtmp=JSON_GetVariable(jsonid,jsonpath)
				Rename vtmp,$(RemoveBadCharacters(toplevelkeys[counter]))
				break
			case 3:	//String
				String/G stmp
				stmp = JSON_GetString(jsonid,jsonpath)
//				print toplevelkeys[counter]
//				print RemoveBadCharacters(toplevelkeys[counter])
				Rename stmp,$(RemoveBadCharacters(toplevelkeys[counter]))
				break
			case 4:	//Boolean
				Variable/G vtmp
				JSONXOP_GetValue/V jsonID, jsonpath
				vtmp=V_value
				Rename vtmp,$(RemoveBadCharacters(toplevelkeys[counter]))
				break
		EndSwitch
		counter+=1
	while(counter<nkeys)
	JSON_Release(jsonid)
	SetDataFolder ::
	// DATA
	data = contents[pos+6, strlen(contents)-1]
	Wave/T tmp=ListToTextWave(data, "\r")
	String s_tmp = tmp[0]
	Wave/T headerwave = ListToTextWave(s_tmp, "\t")
	Make/T/N=(numpnts(tmp)-2,numpnts(headerwave)) tmp2
	Wave/T tmp2
	counter=0
	do
		s_tmp = tmp[counter+1]
		Wave/T tmp3 = ListToTextWave(s_tmp, "\t")
		tmp2[counter][]=tmp3[q]
		
		counter+=1
	while(counter<dimsize(tmp,0)-2)
	counter=0
	String twoD
	SVAR/Z instrument=:Header:General:Instrument_s__0:Instrument
	if(!SVAR_Exists(instrument))
		twoD="*2D Image*"
	else
		twoD="*"+instrument+"*"
	endif
	do
		if(stringmatch(headerwave[counter],"*Time of Day*")==1 || stringmatch(headerwave[counter],twoD)==1)
			make/T/N=(dimsize(tmp2,0)) wwt
			wwt[] = tmp2[p][counter]
			Rename wwt, $(headerwave[counter])
		else
			make/N=(dimsize(tmp2,0)) ww
			ww[] = str2num(tmp2[p][counter])
			Rename ww, $(headerwave[counter])
		endif
		counter+=1
	while(counter<dimsize(tmp2,1))
	KillWaves/Z tmp2
	
	SVAR scantype=:Header:Scan_Type
	String imname
	Variable imagecounter=0
	StrSwitch(scantype)
		case "Image Single Motor Scan":
		case "Single Motor Scan":
			String wavenamelist
			if(SVAR_Exists(instrument))
				wavenamelist = instrument
			else
				wavenamelist = "2D Image"
			endif
			wave/T imagelist=$wavenamelist
			SVAR/Z fileext=:Header:Image_Single_Motor_Scan:Save_Images_As
			if(!SVAR_Exists(fileext))
				SVAR/Z fileext=:Header:General:Instrument_s__0:Save_As
			endif
			NewDataFolder/S Images
				Strswitch(fileext)
					case "png":
						Variable images=numpnts(imagelist)
						if(images!=0)
							do
								imname = impath+ReplaceString("\\",replacestring("..\\",imagelist[imagecounter],""),":")
								// Check if file exists instead of using /Z below?
								ImageLoad/T=rpng/Q/Z imname
								imagecounter+=1
							while(imagecounter<images)
						endif
						break
					Default:
						print fileext+" not yet coded"
						break
				EndSwitch
			SetDataFolder ::
			break
		Default:
			print "Need to code up a new case!"
			break
	EndSwitch
	SetDataFolder $original
	DuplicateDataFolder $(original+":"+fname), $(treated+":"+fname) 
	SetDataFolder saveDF
End

Function NeXusConverter() : Panel
	String basefolder="root:NexusConverter"
	String packagename="HiRRIXS"
	String windowname=packagename+"Panel"
	String original="root:Original"
	String treated="root:Treated"
	Variable left=930, top=40
	Variable width=780, height=970
	Variable right=left+width, bottom=top+height
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(left,top,right,bottom)/N=$windowname as packagename
	SetWindow $windowname, userdata(basefolder)=basefolder
	SetWindow $windowname, userdata(package)+=packagename
	SetWindow $windowname, userdata(windowname)+=windowname
	SetWindow $windowname, userdata(original)+=original
	SetWindow $windowname, userdata(treated)+=treated
	Button bu_SelectFolder,pos={20,20},size={100.00,30.00},title="Folder on disk:", proc=bu_SelectConvFolder_proc
	Button button_load_one, pos={450,20}, size={100,30}, title="Load one", proc=bu_load_one_file
	Button button_load_all, pos={550,20}, size={100,30}, title="Load all"//, proc=bu_load_all
	PopupMenu pu_files,pos={130.00,20.00},size={51.00,23.00},fSize=12
	PopupMenu pu_files,mode=0,userdata(basefolder)=basefolder
	PopupMenu pu_filetype,pos={350.00,20.00},size={51.00,23.00},fSize=12
	PopupMenu pu_filetype,mode=1,popvalue=".txt",value= #"\".txt;.png;.jpg;.tif;.csv\""
	TitleBox t_set,pos={37.00,54.00},size={91.00,19.00},title="Loaded data sets:"
	PopupMenu popup_origfolder,pos={30,73},size={50.00,23.00}, proc=pu_origfolder
	PopupMenu popup_origfolder,mode=1,value=popuporigfolderlist()
	TitleBox t_imageset,pos={37.00,505.00},size={91.00,19.00},title="Loaded data sets:"
	PopupMenu popup_origimagefolder,pos={30,524},size={50.00,23.00}, proc=pu_origimagefolder
	PopupMenu popup_origimagefolder,mode=1,value=popuporigimagefolderlist()
	PopupMenu popup_images,pos={300,524},size={50.00,23.00},proc=pu_images
	PopupMenu popup_images,mode=1,value=popupimagelist()
//	PopupMenu popup_image,pos={280,73},size={50.00,23.00}//, proc=pu_image
//	PopupMenu popup_image,mode=1,popvalue="Select a folder first",value= #"\"Select a folder first\""
	PopupMenu popup_energy,pos={130,100},size={50.00,23.00}, value="None", proc=pu_waves
	PopupMenu popup_izero,pos={130,125},size={50.00,23.00}, value="None", proc=pu_waves
	PopupMenu popup_det1,pos={130,150},size={50.00,23.00}, value="None", proc=pu_waves
	PopupMenu popup_det2,pos={130,175},size={50.00,23.00}, value="None", proc=pu_waves
	PopupMenu popup_det3,pos={130,200},size={50.00,23.00}, value="None", proc=pu_waves
	PopupMenu popup_det4,pos={130,225},size={50.00,23.00}, value="None", proc=pu_waves
	TitleBox t_energy, pos={30,100}, title="Energy/indep.axis:"
	TitleBox t_xmotor, pos={350,100},frame=0,title="X-motor:"
	SetVariable sv_xmotor, pos={400,98},size={150,23},frame=0,fstyle=0,title=" ",limits={1,-1,0},noedit=1
	TitleBox t_izero, pos={30,125}, title="Izero:"
	TitleBox t_det1, pos={30,150}, title="Detector 1:"
	TitleBox t_det2, pos={30,175}, title="Detector 2:"
	TitleBox t_det3, pos={30,200}, title="Detector 3:"
	TitleBox t_det4, pos={30,225}, title="Detector 4:"
	Titlebox t_abs, pos={280,125}, title="Absorbed"
	Titlebox t_tey, pos={340,125}, title="TEY"
	Titlebox t_tfyc, pos={400,125}, title="Channeltron"
	Titlebox t_tfyd, pos={460,125}, title="Diode"
	Titlebox t_sdd, pos={520,125}, title="SDD"
	Titlebox t_none, pos={580,125}, title="None"
	Variable tableleft=280,horizontalspacing=60
	Variable tabletop=150,verticalspacing=25
	CheckBox ch_abs1, pos={tableleft,tabletop}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_tey1, pos={tableleft+horizontalspacing,tabletop}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_tfyc1, pos={tableleft+2*horizontalspacing,tabletop}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_tfyd1, pos={tableleft+3*horizontalspacing,tabletop}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_sdd1, pos={tableleft+4*horizontalspacing,tabletop}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_none1, pos={tableleft+5*horizontalspacing,tabletop}, title=" ",value=1, mode=1, proc=ch_radiobutton
	CheckBox ch_abs2, pos={tableleft,tabletop+verticalspacing}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_tey2, pos={tableleft+horizontalspacing,tabletop+verticalspacing}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_tfyc2, pos={tableleft+2*horizontalspacing,tabletop+verticalspacing}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_tfyd2, pos={tableleft+3*horizontalspacing,tabletop+verticalspacing}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_sdd2, pos={tableleft+4*horizontalspacing,tabletop+verticalspacing}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_none2, pos={tableleft+5*horizontalspacing,tabletop+verticalspacing}, title=" ",value=1, mode=1, proc=ch_radiobutton
	CheckBox ch_abs3, pos={tableleft,tabletop+2*verticalspacing}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_tey3, pos={tableleft+horizontalspacing,tabletop+2*verticalspacing}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_tfyc3, pos={tableleft+2*horizontalspacing,tabletop+2*verticalspacing}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_tfyd3, pos={tableleft+3*horizontalspacing,tabletop+2*verticalspacing}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_sdd3, pos={tableleft+4*horizontalspacing,tabletop+2*verticalspacing}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_none3, pos={tableleft+5*horizontalspacing,tabletop+2*verticalspacing}, title=" ",value=1, mode=1, proc=ch_radiobutton
	CheckBox ch_abs4, pos={tableleft,tabletop+3*verticalspacing}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_tey4, pos={tableleft+horizontalspacing,tabletop+3*verticalspacing}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_tfyc4, pos={tableleft+2*horizontalspacing,tabletop+3*verticalspacing}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_tfyd4, pos={tableleft+3*horizontalspacing,tabletop+3*verticalspacing}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_sdd4, pos={tableleft+4*horizontalspacing,tabletop+3*verticalspacing}, title=" ",value=0, mode=1, proc=ch_radiobutton
	CheckBox ch_none4, pos={tableleft+5*horizontalspacing,tabletop+3*verticalspacing}, title=" ",value=1, mode=1, proc=ch_radiobutton
	// Image
	Slider slider_LowLimit pos={520,555},size={55,300},vert=1,disable=1,proc=slider_lowlim_proc//,repeat={1,0,10,0},proc=slider_lowlim_proc
	Slider slider_HighLimit pos={575,555},size={55,300},vert=1,disable=1,proc=slider_highlim_proc//,repeat={1,0,10,0},proc=slider_highlim_proc
	Button button_nextimage pos={633,524},size={20,20},title="⬇️"
	Button button_previousimage pos={660,524},size={20,20},title="⬆️"
	PopupMenu popup_ctab, pos={520,875},value="*COLORTABLEPOP*",proc=popup_ctab_proc
	TitleBox t_zap pos={650,575},frame=0,title="Zap"
	CheckBox ch_zap pos={680,571},title=" ",proc=ch_zap_proc
	SetVariable sv_threshhold pos={700,571},title=" ",value=_NUM:3,proc=sv_threshhold_proc
	TitleBox t_dark pos={650,600},frame=0,title="Dark"
	CheckBox ch_dark pos={680,596},title=" ",proc=ch_dark_proc
	TitleBox t_bin pos={650,625},frame=0,title="Bin:"
	PopupMenu popup_bin, pos={680,621},value=" ;2;4;8;16;32;64;128;256", proc=popup_bin_proc
	TitleBox t_graph pos={650,650},frame=0,title="Graph"
	CheckBox ch_graph pos={680,646},title=" ",proc=ch_graph_proc
	TitleBox t_reset pos={650,675},frame=0,title="Reset"
	Button bu_reset pos={680,671},size={15,15},title="\Z14☠︎"
	TitleBox t_curvature pos={650,700},frame=0,title="Curvature"
	CheckBox ch_calcCurv pos={700,696},title=" ",proc=ch_calcCurv_proc
	TitleBox t_applyCurv pos={650,725},frame=0,title="Apply Curv"
	CheckBox ch_applyCurv pos={700,721},title=" ",proc=ch_applyCurv_proc
	Button b_zoomOut pos={650,750},title="Zoom Out",size={70,20}, proc=b_zoomOut_proc
//	TitleBox t_image,pos={286.00,54.00},size={37.00,19.00},title="Image:"
//	Button button_Plot_one,pos={280,95},size={70.00,20.00},title="Plot one"//, proc=bu_plot
	Button button_Convert_set,pos={700,225},size={70.00,20.00},title="Convert", proc=bu_convert_set
	Button button_next,pos={700,83},size={70,20},title="Next"//, proc=bu_nextimg
	Button button_previous,pos={700,63},size={70,20},title="Previous"//,proc=bu_previmg
//	Button button_Extract_widths,pos={30,120},size={120,20},title="Extract widths"//,proc=bu_extract_widths
End //Macro

Function bu_SelectConvFolder_proc(B_STRUCT) : ButtonControl
	STRUCT WMButtonAction &B_Struct
	Switch(B_Struct.eventCode)
		case 2:
			String basefolder=GetUserData("","","basefolder")
			SVAR impath=$(basefolder+":impath")
			newpath/Q/M="Please select the folder with the files to convert"/O path
			if(!V_flag)
				pathinfo path
				impath=S_path
//				SetVariable sv_selectedFolder value=impath
				PopupMenu pu_files mode=1,value=Populate_pufiles()
			endif
			break
	EndSwitch
	Return 0
End

Function/S Populate_pufiles()
	String basefolder
	basefolder=GetUserData("","","basefolder")
	String wname=GetUserData("","","windowname")
//	String basefolder="root:NeXusConverter"
	SVAR impath=$(basefolder+":impath")
	String imlist,type
	ControlInfo/W=$wname pu_filetype
	type=S_Value
	type=".txt"
	NewPath/O/Q path, impath
	imlist=IndexedFile(path,-1,type)
	imlist=SortList(imlist,";",16)
	imlist=ReplaceString(type,imlist,"")
	Return imlist
End

Function bu_load_one_file(ctrlName)
	String ctrlName
	String basefolder=GetUserData("","","basefolder")
	String wname=GetUserData("","","windowname")
	String origbase=GetUserData("","","original")+":"
	SVAR impath=$(basefolder+":impath")
	ControlInfo/W=$wname pu_files
	String filename=S_Value
	String foldername=Replacestring(" ", filename, "_")
	if(!DataFolderExists(origbase+foldername))
		load_file(filename)
		PopupMenu popup_origfolder value=popuporigfolderlist()
	endif
	PopupMenu popup_origfolder value=popuporigfolderlist()
End

Function pu_origfolder(PU_Struct) : PopupMenuControl
// Set the chosen item and update the options for the signal waves
	STRUCT WMPopupAction &PU_Struct
	PU_Struct.blockreentry=1
	Switch(PU_Struct.eventCode)
		case 2:
			PopupMenu popup_origfolder mode=PU_Struct.popnum
			PopupMenu popup_energy value=Populate_puwaves()
			PopupMenu popup_izero value=Populate_puwaves()
			PopupMenu popup_det1 value=Populate_puwaves()
			PopupMenu popup_det2 value=Populate_puwaves()
			PopupMenu popup_det3 value=Populate_puwaves()
			PopupMenu popup_det4 value=Populate_puwaves()
			String treated=GetUserData("","","treated")
			SVAR scantype=$(treated+":"+PU_Struct.popStr+":Header:Scan_Type")
			SVAR xmotor=$(treated+":"+PU_Struct.popStr+":Header:"+ReplaceString(" ",scantype,"_")+":X_Motor")
			SetVariable sv_xmotor value=xmotor
			DisplayGraph()
	EndSwitch
End

Function/S popuporigfolderlist()
// Populate the list of options in pu_origfolder on the fly.
	DFREF saveDF = GetDataFolderDFR()
	String original=GetUserData("","","original")
	SetDataFolder $original
	DFREF origfolder = GetDataFolderDFR()
	Variable nofolders, counter=0
	nofolders=CountObjectsDFR(origfolder,4)
	String list=""
		for(counter=0;counter<nofolders;counter++)
			list=AddListItem(GetIndexedObjNameDFR(origfolder,4,counter),list,";",inf)
		endfor
	SetDataFolder saveDF
	Return list
End

Function pu_origimagefolder(PU_Struct) : PopupMenuControl
// Set the chosen item
	STRUCT WMPopupAction &PU_Struct
	PU_Struct.blockreentry=1
	Switch(PU_Struct.eventCode)
		case 2:
			PopupMenu popup_origimagefolder mode=PU_Struct.popnum
			PopupMenu popup_images value=populateimagelist()
			DisplayImage()
	EndSwitch
End

Function/S populateimagelist()
	DFREF saveDF = GetDataFolderDFR()
	String basefolder=GetUserData("","","basefolder")
	String wname=GetUserData("","","windowname")
	String origbase=GetUserData("","","original")
	SetDataFolder $origbase
	ControlInfo/W=$wname popup_origimagefolder
	String datafolder=S_Value
	SetDataFolder $datafolder
	if(DataFolderExists("Images"))
		SetDataFolder Images
		DFREF imagefolder = GetDataFolderDFR()
		Variable noimages, counter=0
		noimages=CountObjectsDFR(imagefolder,1)
		String list=""
		for(counter=0;counter<noimages;counter++)
			list=AddListItem(GetIndexedObjNameDFR(imagefolder,1,counter),list,";",inf)
		endfor
	else
		list="None;"
	endif
	SetDataFolder saveDF
	Return list
End

Function/S popuporigimagefolderlist()
// Populate the list of options in pu_origimagefolder on the fly.
// This is basically the same as pu_origfolder, except intended to supply options for images
	DFREF saveDF = GetDataFolderDFR()
	String original=GetUserData("","","original")
	SetDataFolder $original
	DFREF origfolder = GetDataFolderDFR()
	Variable nofolders, counter=0
	nofolders=CountObjectsDFR(origfolder,4)
	String list=""
		for(counter=0;counter<nofolders;counter++)
			list=AddListItem(GetIndexedObjNameDFR(origfolder,4,counter),list,";",inf)
		endfor
	SetDataFolder saveDF
	Return list
End

Function pu_images(PU_Struct) : PopupMenuControl
// Set the selected image
	STRUCT WMPopupAction &PU_Struct
	PU_Struct.blockreentry=1
	Switch(PU_Struct.eventCode)
		case 2:
			PopupMenu popup_images mode=PU_Struct.popnum
			String wname=GetUserData("","","windowname")
			String image=PU_Struct.popstr
			String parastr
			ControlInfo/W=$wname popup_bin
			String bin=S_Value
			if(cmpstr(bin," ")==0)
				parastr="_Parameters':"
			else
				parastr="_Parameters_"+bin+"':"
			endif
			if(!DataFolderExists(":'"+image+parastr))
				PopupMenu popup_bin mode=1
			endif
			DisplayImage()
			break
	EndSwitch
end

Function CreateImageParameters()
	DFREF saveDF = GetDataFolderDFR()
	String basefolder=GetUserData("","","basefolder")
	String wname=GetUserData("","","windowname")
	String treated=GetUserData("","","treated")
	ControlInfo/W=$wname popup_origimagefolder
	String fname=S_Value
	ControlInfo/W=$wname popup_images
	String imname=S_Value
	ControlInfo/W=$wname popup_bin
	String bin=S_Value
	SetDataFolder $(treated+":"+fname+":Images")
	
	if(cmpstr(bin," ")==0)
		Wave ww=$imname
		NewDataFolder/O/S $(treated+":"+fname+":Images:'"+imname+"_Parameters'")
	else
		Wave ww=$(imname+bin)
		NewDataFolder/O/S $(treated+":"+fname+":Images:'"+imname+"_Parameters_"+bin+"'")
	endif
	ImageStats ww
	Variable/G maxint=V_max
	Variable/G minint=V_min
	Variable/G zap=0
	Variable/G dark=0
	Variable/G graph=0
	Variable/G threshhold
	Variable/G curvature
	Variable/G applyCurv
	String/G ctable/N=ctable
	ctable="PlanetEarth"
	NVAR/Z maxdisp=maxdisp
	NVAR/Z mindisp=mindisp
	if(!NVAR_exists(maxdisp))
		Variable/G maxdisp=maxint
	endif
	if(!NVAR_exists(mindisp))
		Variable/G mindisp=minint
	endif
	CheckBox ch_zap value=0
	CheckBox ch_dark value=0
	CheckBox ch_graph value=0
	Variable m = 1 + WhichListItem(ctable, CTabList())
	PopupMenu popup_ctab mode=m
	SetDataFolder saveDF
End

Function/S popupimagelist()			// fixyfixy
// Populate popup_images... do i need this? I can populate the available images in the above function.
	DFREF saveDF = GetDataFolderDFR()
	String basefolder=GetUserData("","","basefolder")
	String wname=GetUserData("","","windowname")
	String origbase=GetUserData("","","original")
	SetDataFolder $origbase
	DFREF origfolder = GetDataFolderDFR()
	ControlInfo/W=$wname popup_origimagefolder
	String datafolder=S_Value
	SetDataFolder $datafolder
	Variable nofolders, counter=0
	nofolders=CountObjectsDFR(origfolder,4)
	String list=""
		for(counter=0;counter<nofolders;counter++)
			list=AddListItem(GetIndexedObjNameDFR(origfolder,4,counter),list,";",inf)
		endfor
	SetDataFolder saveDF
	Return list
End

Function pu_waves(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct
	PU_Struct.blockreentry=1
	String puname=PU_Struct.ctrlName
	Switch(PU_Struct.eventCode)
		case 2:
			PopupMenu $(puname) mode=PU_Struct.popnum
//			PopupMenu popup_image value=popupimagelist()
			DisplayGraph()
	EndSwitch
End

Function/S Populate_puwaves()
	DFREF saveDF = GetDataFolderDFR()
	String basefolder
	basefolder=GetUserData("","","basefolder")
	String original=GetUserData("","","original")+":"
	ControlInfo popup_origfolder
	SetDataFolder $(original+S_Value)
	DFREF wavefolder = GetDataFolderDFR()
	Variable nowaves, counter=0
	nowaves=CountObjectsDFR(wavefolder,1)
	String list="None;"
		for(counter=0;counter<nowaves;counter++)
			list=AddListItem(GetIndexedObjNameDFR(wavefolder,1,counter),list,";",inf)
		endfor
	SetDataFolder saveDF
	Return list
End

Function ch_radiobutton(cb) : CheckBoxControl
	STRUCT WMCheckboxAction& cb
	
	switch(cb.eventCode)
		case 2:
			handleradiobutton(cb.ctrlname)
			DisplayGraph()
			break
	endswitch
	
	return 0
End

Function handleradiobutton(ctrlName)
	String ctrlName
	Variable selected
	Variable line=str2num(ctrlname[strlen(ctrlname)-1])
	String column=ctrlname[0,strlen(ctrlname)-2]
	StrSwitch(column)
		case "ch_abs":
			selected=1
			break
		case "ch_tey":
			selected=2
			break
		case "ch_tfyc":
			selected=3
			break
		case "ch_tfyd":
			selected=4
			break
		case "ch_sdd":
			selected=5
			break
		case "ch_none":
			selected=6
			break
	endswitch
	CheckBox $("ch_abs"+num2str(line)), value = selected==1
	CheckBox $("ch_tey"+num2str(line)), value = selected==2
	CheckBox $("ch_tfyc"+num2str(line)), value = selected==3
	CheckBox $("ch_tfyd"+num2str(line)), value = selected==4
	CheckBox $("ch_sdd"+num2str(line)), value = selected==5
	CheckBox $("ch_none"+num2str(line)), value = selected==6
End

Function DisplayGraph()					///////  FIX to display treated
	String basefolder=GetUserData("","","basefolder")
	String wname=GetUserData("","","windowname")
	SVAR impath=$(basefolder+":impath")
	String original=GetUserData("","","original")
	DFREF saveDF = GetDataFolderDFR()
	SetDataFolder $original
	ControlInfo/W=$wname popup_origfolder
	String w_name=S_Value, w_folder
	w_folder=original+":"+w_name
	SetDataFolder $w_folder
	ControlInfo/W=$wname popup_energy
	String indep_name=S_Value
	ControlInfo/W=$wname popup_izero
	String izero_name=S_Value
	ControlInfo/W=$wname popup_det1
	String det1_name=S_Value
	ControlInfo/W=$wname popup_det2
	String det2_name=S_Value
	ControlInfo/W=$wname popup_det3
	String det3_name=S_Value
	ControlInfo/W=$wname popup_det4
	String det4_name=S_Value
	Wave/Z indep_wave=$indep_name
	Wave/Z izero_wave=$izero_name
	Wave/Z det1_wave=$det1_name
	Wave/Z det2_wave=$det2_name
	Wave/Z det3_wave=$det3_name
	Wave/Z det4_wave=$det4_name
	KillWindow/Z $(wname+"#subGraph")
	KillWindow/Z $(wname+"#subGraph0")
	Display/HOST=$wname/N=subGraph/W=(10,265,500,500)

		if(WaveExists(det1_wave))
			if(WaveExists(indep_wave))
				AppendToGraph det1_wave vs indep_wave
			else
				AppendToGraph det1_wave
			endif
		endif

	SetActiveSubWindow $wname
	SetDataFolder saveDF
End

Function DisplayImage()
	String basefolder=GetUserData("","","basefolder")
	String wname=GetUserData("","","windowname")
	SVAR impath=$(basefolder+":impath")
	String treated=GetUserData("","","treated")
	DFREF saveDF = GetDataFolderDFR()
	SetDataFolder $treated
	ControlInfo/W=$wname popup_origimagefolder
	String w_name=S_Value, w_folder
	w_folder=treated+":"+w_name
	SetDataFolder $w_folder
	if(DataFolderExists("Images"))
		SetDataFolder Images
		KillWindow/Z $(wname+"#subImage")
		KillWindow/Z $(wname+"#subImage0")
		KillWindow/Z $(wname+"#subImage1")
		Display/Host=$wname/N=subImage/W=(10,550,500,900)
		ControlInfo/W=$wname popup_images
		String image=S_Value
		ControlInfo/W=$wname popup_bin
		String bin=S_Value
		String parastr
		if(cmpstr(bin," ")==0)
			parastr="_Parameters':"
		else
			parastr="_Parameters_"+bin+"':"
		endif
		// check if wave exists. if not, set 'bin' to " " and reset parastr before proceeding.
		String suffix=""
		if(cmpstr(image,"None")==0)
			//
		else
			if(!DataFolderExists(":'"+image+parastr))
				CreateImageParameters()
			endif
			NVAR dark=$(":'"+image+parastr+"dark")
			if(dark)
				suffix+="D"
			endif
			NVAR zap=$(":'"+image+parastr+"zap")
			if(zap)
				suffix+="Z"
			endif
			NVAR curvature=$(":'"+image+parastr+"curvature")
			if(curvature)
//				suffix+="C"
			endif
			NVAR applyCurv=$(":'"+image+parastr+"applyCurv")
			if(applyCurv)
				suffix+="Corr"
			endif
			if(cmpstr(bin," ")!=0)
				suffix+=bin
			endif
			wave imagew=$(image+suffix)
			NVAR maxint=$(":'"+image+parastr+"maxint")
			NVAR minint=$(":'"+image+parastr+"minint")
			NVAR maxdisp=$(":'"+image+parastr+"maxdisp")
			NVAR mindisp=$(":'"+image+parastr+"mindisp")
			NVAR graph=$(":'"+image+parastr+"graph")
			SVAR ctable=$(":'"+image+parastr+"ctable")
			AppendImage/W=$(wname+"#subImage") imagew
//			ModifyImage '' ctab= {*,*,PlanetEarth,0}
			ModifyImage '' ctab={mindisp,maxdisp,$ctable,0}
//			ModifyImage/W=$(wname+"#subImage") ctab={mindisp,maxdisp,$ctable,0}
			Slider slider_LowLimit disable=0,limits={minint,maxdisp,1},value=mindisp,ticks=10
			Slider slider_HighLimit disable=0,limits={mindisp,maxint,1},value=maxdisp,ticks=10
			CheckBox ch_zap value=zap
			CheckBox ch_dark value=dark
			CheckBox ch_graph value=graph
			Variable m = 1 + WhichListItem(ctable, CTabList())
			PopupMenu popup_ctab mode=m
			Variable pnts=DimSize(imagew,2)
			if(!applyCurv)
				Make/N=(pnts)/O/D $(":'"+image+suffix+"1D'")
			endif
			Wave summed= $(":'"+image+suffix+"1D'")
			if(!applyCurv)
				SumDimension/D=1/DEST=summed imagew
			endif
			AppendToGraph/W=$(wname+"#subImage")/R=sumaxis summed
			Variable plot=(graph==0?1:0)
			ModifyGraph/W=$(wname+"#subImage") standoff(sumaxis)=0,tick(sumaxis)=3,noLabel(sumaxis)=2,freePos(sumaxis)=0,hideTrace=plot
			
		endif
	endif
	SetActiveSubWindow $wname
	SetDataFolder saveDF
End

Function slider_lowlim_proc(S_Struct) : SliderControl
	STRUCT WMSliderAction &S_Struct
	Switch(S_Struct.eventCode)
		case 1:
		case 4:
		case 8:
		case 9:
//		case 16:
//		if(S_Struct.eventCode & 24)
			String treated=GetUserData("","","treated")
			String wname=GetUserData("","","windowname")
			ControlInfo/W=$wname popup_origimagefolder
			String folder=S_Value
			ControlInfo/W=$wname popup_images
			String image=S_Value
			ControlInfo/W=$wname popup_bin
			String bin=S_Value
			String parastr
			if(cmpstr(bin," ")==0)
				parastr="_Parameters':"
			else
				parastr="_Parameters_"+bin+"':"
			endif
			NVAR mindisp=$(treated+":"+folder+":Images:'"+image+parastr+"mindisp")
			mindisp=S_Struct.curval
			Slider slider_LowLimit, value=mindisp
			DisplayImage()
//			ModifyImage/W=$(wname+"#subImage") $image ctab={mindisp,,,0}
			break
//		endif
	endSwitch
	return 0
End

Function slider_highlim_proc(S_Struct) : SliderControl
	STRUCT WMSliderAction &S_Struct
	Switch(S_Struct.eventCode)
		case 1:
		case 4:
		case 8:
		case 9:
//		case 16:
			String treated=GetUserData("","","treated")
			String wname=GetUserData("","","windowname")
			ControlInfo/W=$wname popup_origimagefolder
			String folder=S_Value
			ControlInfo/W=$wname popup_images
			String image=S_Value
			ControlInfo/W=$wname popup_bin
			String bin=S_Value
			String parastr
			if(cmpstr(bin," ")==0)
				parastr="_Parameters':"
			else
				parastr="_Parameters_"+bin+"':"
			endif
			NVAR maxdisp=$(treated+":"+folder+":Images:'"+image+parastr+"maxdisp")
			maxdisp=S_Struct.curval
			Slider slider_HighLimit, value=maxdisp
			DisplayImage()
//			ModifyImage/W=$(wname+"#subImage") $image ctab={,maxdisp,,0}
			break
	endSwitch
	return 0
End

Function ch_zap_proc(cb) : CheckBoxControl
	STRUCT WMCheckboxAction& cb
	switch(cb.eventCode)
		case 2:
			String treated=GetUserData("","","treated")
			String wname=GetUserData("","","windowname")
			ControlInfo/W=$wname popup_origimagefolder
			String folder=S_Value
			ControlInfo/W=$wname popup_images
			String image=S_Value
			ControlInfo/W=$wname popup_bin
			String bin=S_Value
			ControlInfo/W=$wname sv_threshhold
			Variable threshhold=V_Value
			String parastr,suffix=""
			if(cmpstr(bin," ")==0)
				parastr="_Parameters':"
				bin=""
			else
							parastr="_Parameters_"+bin+"':"	
			endif
			NVAR zapbox=$(treated+":"+folder+":Images:'"+image+parastr+"zap")
			NVAR darkbox=$(treated+":"+folder+":Images:'"+image+parastr+"dark")
			print treated+":"+folder+":Images:'"+image+parastr+"zap"
			zapbox=cb.checked
			if(darkbox)
				suffix+="D"
			endif
			Variable passedTime, timerRefNum
			if(zapbox)
				DFREF cdf=GetDataFolderDFR()
				SetDataFolder $(treated+":"+folder+":Images")
				Wave imgwave=$(image+bin)
				timerRefNum = StartMSTimer
				if(exists("XOPzap"))
					Variable res
					Duplicate/FREE imgwave, zapped
					res = XOPzap(imgwave, threshhold, zapped)
					if(res)
						Wave zapped=zap(imgwave,threshhold)
					endif
				else
					Wave zapped=zap(imgwave,threshhold)
				endif
				passedTime = StopMSTimer(timerRefNum)
				Print "Time spent zapping: ", passedTime
				suffix+="Z"
				suffix+=bin
				KillWaves/Z $(image+suffix)
				MoveWave zapped, $(image+suffix)
				SetDataFolder cdf
			endif
			DisplayImage()
			break
	endswitch
	
	return 0
End

Function sv_threshhold_proc(SV_Struct) : SetVariableControl
	STRUCT WMSetVariableAction &SV_Struct
	switch(SV_Struct.eventCode)
		case 2:
			String treated=GetUserData("","","treated")
			String wname=GetUserData("","","windowname")
			ControlInfo/W=$wname popup_origimagefolder
			String folder=S_Value
			ControlInfo/W=$wname popup_images
			String image=S_Value
			String parastr
			parastr="_Parameters':"
			NVAR threshhold=$(treated+":"+folder+":Images:'"+image+parastr+"threshhold")
			threshhold=SV_Struct.dval
			break
	EndSwitch
	
	return 0
End

Function ch_dark_proc(cb) : CheckBoxControl
	STRUCT WMCheckBoxAction &cb
	Switch(cb.eventCode)
		case 2:
			String treated=GetUserData("","","treated")
			String wname=GetUserData("","","windowname")
			ControlInfo/W=$wname popup_origimagefolder
			String folder=S_Value
			ControlInfo/W=$wname popup_images
			String image=S_Value
			String parastr
			parastr="_Parameters':"
			NVAR dark=$(treated+":"+folder+":Images:'"+image+parastr+"dark")
			dark=cb.checked
			NVAR zapbox=$(treated+":"+folder+":Images:'"+image+parastr+"zap")
			String suffix=""
			if(zapbox)
				suffix+="Z"
			endif
			if(dark)
				DFREF cdf=GetDataFolderDFR()
				SetDataFolder $(treated+":"+folder+":Images")
				Wave imgwave=$(image+suffix)
				suffix+="D"
				Duplicate/O/FREE imgwave,darkw		/// make dark image subtracted wave here
				KillWaves/Z $(image+suffix)
				MoveWave darkw, $(image+suffix)
			endif
			DisplayImage()
			break
	EndSwitch
	Return 0
End

Function ch_graph_proc(cb) : CheckBoxControl
	STRUCT WMCheckboxAction& cb
	switch(cb.eventCode)
		case 2:
			String treated=GetUserData("","","treated")
			String wname=GetUserData("","","windowname")
			ControlInfo/W=$wname popup_origimagefolder
			String folder=S_Value
			ControlInfo/W=$wname popup_images
			String image=S_Value
			ControlInfo/W=$wname popup_bin
			String bin=S_Value
			String parastr
			if(cmpstr(bin," ")==0)
				parastr="_Parameters':"
			else
				parastr="_Parameters_"+bin+"':"
			endif
			NVAR graph=$(treated+":"+folder+":Images:'"+image+parastr+"graph")
			graph=cb.checked
			DisplayImage()
			break
	endswitch
	
	return 0
End

Function ch_calcCurv_proc(CB_Struct) : CheckBoxControl
	STRUCT WMCheckboxAction &CB_Struct
	switch(CB_Struct.eventCode)
		case 2:
			String treated=GetUserData("","","treated")
			String wname=GetUserData("","","windowname")
			ControlInfo/W=$wname popup_origimagefolder
			String folder=S_Value
			ControlInfo/W=$wname popup_images
			String image=S_Value
			ControlInfo/W=$wname popup_bin
			String bin=S_Value
			ControlInfo/W=$wname ch_zap
			Variable zapbox=V_Value
			ControlInfo/W=$wname ch_dark
			Variable darkbox=V_Value
			String parastr,suffix=""
			if(cmpstr(bin," ")==0)
				parastr="_Parameters'"
				bin=""
			else
							parastr="_Parameters_"+bin+"'"	
			endif
			NVAR curvebox=$(treated+":"+folder+":Images:'"+image+parastr+":curvature")
			curvebox=CB_Struct.checked
			if(zapbox)
				suffix+="Z"
			endif
			if(darkbox)
				suffix+="D"
			endif
			if(cmpstr(bin," ")==0)
				bin=""
			endif
			suffix+=bin
			if(curvebox)
				DFREF cdf=GetDataFolderDFR()
				SetDataFolder $(treated+":"+folder+":Images")
				Wave imagew=$(image+suffix)
				Variable vertAxisMin,vertAxisMax,horAxisMin,horAxisMax,detectedCurvature
				// use GetAxis to get the range of the axis
				GetAxis/W=$(wname+"#subImage")/Q bottom
				horAxisMin=V_min
				horAxisMax=V_max
				GetAxis/W=$(wname+"#subImage")/Q left
				vertAxisMin=V_min
				vertAxisMax=V_max
				// make a FREE wave that is the size of the displayed image
				Duplicate/O/R=(horAxisMin,horAxisMax)(vertAxisMin,vertAxisMax)/FREE imagew,tmpImage
				SetDataFolder $(":'"+image+parastr)
				// Send this wave to detectCurvature()
				detectedCurvature=detectCurvature(tmpImage)
				Wave fit=fit__free_
				Duplicate/O fit, curvatureWave
				Wave curvatureWave
				Wave W_coef
				Duplicate/O W_coef, curveCoef
				curvatureWave+=horAxisMin
				AppendToGraph/VERT/W=$(wname+"#subImage") curvatureWave
//				ModifyGraph/W=$(wname+"#subImage") offset(curvatureWave)={0,horAxisMin}
				SetDataFolder cdf
			endif
			break
	endSwitch
	
	return 0
End

Function ch_applyCurv_proc(CB_STRUCT) : CheckBoxControl
STRUCT WMCheckboxAction &CB_Struct
	switch(CB_Struct.eventCode)
		case 2:
			DFREF cdf=GetDataFolderDFR()
			String treated=GetUserData("","","treated")
			String wname=GetUserData("","","windowname")
			ControlInfo/W=$wname popup_origimagefolder
			String folder=S_Value
			ControlInfo/W=$wname popup_images
			String image=S_Value
			ControlInfo/W=$wname popup_bin
			String bin=S_Value
			ControlInfo/W=$wname ch_zap
			Variable zapbox=V_Value
			ControlInfo/W=$wname ch_dark
			Variable darkbox=V_Value
//			ControlInfo/W=$wname cb_applyCurv
//			Variable applybox=V_Value
			String parastr,suffix=""
			if(cmpstr(bin," ")==0)
				parastr="_Parameters'"
				bin=""
			else
							parastr="_Parameters_"+bin+"'"	
			endif
			NVAR applybox=$(treated+":"+folder+":Images:'"+image+parastr+":applyCurv")
			applybox=CB_STRUCT.checked
			SetDataFolder $(treated+":"+folder+":Images")
			if(applybox)
				Wave curvcoef=$(":'"+image+parastr+":curveCoef")
				Wave wv=$image
				img_curve_corr(wv,curvcoef)
				Wave curvCorr
				Wave curvCorr1D
				String newname=image+"Corr"
				String newname1D=image+"Corr1D"
				Duplicate/O curvCorr,$newname
				Duplicate/O curvCorr1D,$newname1d
			endif
			DisplayImage()
			SetDataFolder cdf
			break
	EndSwitch
	
	return 0
End

Function b_zoomOut_proc(B_STRUCT) : ButtonControl
STRUCT WMButtonAction &B_Struct
	switch(B_Struct.eventCode)
		case 2:
			String treated=GetUserData("","","treated")
			String wname=GetUserData("","","windowname")
			ControlInfo/W=$wname popup_origimagefolder
			String folder=S_Value
			ControlInfo/W=$wname popup_images
			String image=S_Value
//			ControlInfo/W=$wname popup_bin
//			String bin=S_Value
//			ControlInfo/W=$wname ch_zap
//			Variable zapbox=V_Value
//			ControlInfo/W=$wname ch_dark
//			Variable darkbox=V_Value
//			String parastr,suffix=""
//			if(cmpstr(bin," ")==0)
//				parastr="_Parameters'"
//				bin=""
//			else
//							parastr="_Parameters_"+bin+"'"	
//			endif
			SetAxis/W=$(wname+"#subImage")/A
			SetActiveSubwindow $wname
			break
	EndSwitch
	
	return 0
End

Function popup_ctab_proc(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct
	Switch (PU_Struct.eventCode)
		case 2:
			String treated=GetUserData("","","treated")
			String wname=GetUserData("","","windowname")
			ControlInfo/W=$wname popup_origimagefolder
			String folder=S_Value
			ControlInfo/W=$wname popup_images
			String image=S_Value
			ControlInfo/W=$wname popup_bin
			String bin=S_Value
			String parastr
			if(cmpstr(bin," ")==0)
				parastr="_Parameters':"
			else
				parastr="_Parameters_"+bin+"':"
			endif
			SVAR ctable=$(treated+":"+folder+":Images:'"+image+parastr+"ctable")
			ctable=PU_Struct.popstr
			DisplayImage()
//			ModifyImage/W=$(wname+"#subImage") $image ctab={,,$ctable,0}
		break
	EndSwitch
End

Function corrwaves()
	String treated=GetUserData("","","treated")
	String wname=GetUserData("","","windowname")
	ControlInfo/W=$wname popup_origimagefolder
	String folder=S_Value
	ControlInfo/W=$wname popup_images
	String image=S_Value
	Wave imagew=$(treated+":"+folder+":Images:'"+image+"'")
	Make/N=2048/O/D $(treated+":"+folder+":Images:'"+image+"_Parameters':"+"tie")
	Wave tie=$(treated+":"+folder+":Images:'"+image+"_Parameters':"+"tie")
	Duplicate/FREE tie,maxtie
	Duplicate/FREE tie,corrtie
	Variable slices=DimSize(imagew,0)
	Variable channels=DimSize(imagew,1)
	Variable midslice=floor(slices/2)
	Variable counter=0,maxpeak,maxpeakloc,maxcorrpeak,maxcorrpeakloc
	Make/FREE/N=(slices)/D midwave=imagew[midslice][p]
	Make/FREE/N=(slices)/D w1
	do
		w1=imagew[counter][p]
		Duplicate/FREE/O w1,wtmp
		FindPeak/Q wtmp
		maxpeak=V_PeakVal
		maxpeakloc=V_PeakLoc
		maxtie[counter]=maxpeakloc
		correlate/NODC/C midwave,wtmp
		FindPeak/Q wtmp
		maxcorrpeak=V_PeakVal
		maxcorrpeakloc=V_PeakLoc
		corrtie[counter]=slices-maxcorrpeakloc 
		counter+=1
	while(counter<slices)
	
	
	tie=corrtie
	
End

Function popup_bin_proc(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct
	Switch (PU_Struct.eventCode)
		case 2:
			String treated=GetUserData("","","treated")
			String wname=GetUserData("","","windowname")
			ControlInfo/W=$wname popup_origimagefolder
			String folder=S_Value
			ControlInfo/W=$wname popup_images
			String image=S_Value
			Wave orig=$(treated+":'"+folder+"':Images:'"+image+"'")
			if(!WaveExists($(treated+":'"+folder+"':Images:'"+image+PU_Struct.popStr+"'")))
				Duplicate/FREE orig,tmpWave
				MatrixTranspose tmpWave
				Redimension/D tmpWave
				if(exists("XOPbin"))
					Make/FREE/N=(DimSize(tmpWave,0)/str2num(PU_Struct.popStr),DimSize(tmpWave,1))/D binned
					print XOPbin(tmpWave,str2num(PU_Struct.popStr),binned)
				else
					Wave binned=Bin(tmpWave,str2num(PU_Struct.popStr))
				endif
				MatrixTranspose binned
//				KillWaves/Z $(treated+":'"+folder+"':Images:'"+image+PU_Struct.popStr+"'")
				MoveWave binned,$(treated+":'"+folder+"':Images:'"+image+PU_Struct.popStr+"'")
			endif
			String binning=PU_Struct.popstr
			String parastr
			if(cmpstr(binning," ")==0)
				parastr="_Parameters':"
			else
				parastr="_Parameters_"+binning+"':"
			endif
			if(!DataFolderExists(":'"+image+parastr))
				CreateImageParameters()
			endif
			DisplayImage()
			break
	EndSwitch
End

Function/WAVE Bin(ww,binning)
	wave ww
	Variable binning
	Duplicate/O/FREE ww,result
	Variable slices = DimSize(ww,1)
	Variable channels = DimSize(ww,0)
	Variable newslices,counter=0,index=0,ii
	if(mod(slices,binning)==0)
		newslices=slices/binning
		ReDimension/N=(channels,newslices) result
		do
			for(ii=counter;ii<counter+binning;ii+=1)
				result[][index]+=ww[p][ii]
			endfor
			
			index+=1
			counter+=binning
		while(counter<slices)
	endif
	return result
End

Function bu_convert_set(ctrlName) : ButtonControl
	String ctrlName
	DFREF saveDF = GetDataFolderDFR()
	String base="root:NeXusConverter:"
	SVAR impath=$(base+"impath")
//	String type
//	ControlInfo pu_filetype
//	type=S_Value
	ControlInfo/W=NeXusConverterPanel popup_origfolder
	String s_folder = S_Value, origfolder
	Wave xas=$("root:AXIS:Original:"+s_folder+":'DIAG133 Izero'")
	Wave energy=$("root:AXIS:Original:"+s_folder+":'Mono Energy UDP Goal'")
	origfolder=base+s_folder
	Variable fileid, entryid, titleid
	String title=s_folder
	killDataFolder/Z root:ToConvert
	NewDataFolder root:ToConvert
	NewDataFolder/S root:ToConvert:entry
	String/G root:ToConvert:entry:title=s_folder
	String/G root:ToConvert:entry:start_time="11:11:11PM"
	String/G root:ToConvert:entry:definition="NXxas"
	CreateNXinstrument("BL6013")
//	NewDataFolder root:ToConvert:entry:instrument
//	NewDataFolder root:ToConvert:entry:source
//	String/G root:ToConvert:entry:source:type=""
//	String/G root:ToConvert:entry:source:name=""
//	String/G root:ToConvert:entry:source:probe="x-ray"
//	NewDataFolder root:ToConvert:entry:source:monochromator
//	Duplicate energy :source:monochromator:energy
//	NewDataFolder root:ToConvert:entry:source:incoming_beam
	Make/N=(numpnts(energy)) :source:incoming_beam:data
	Wave izero=:source:incoming_beam:data
	izero=1
	NewDataFolder root:ToConvert:entry:source:absorbed_beam
	Duplicate xas :source:absorbed_beam:data
	Make/T/N=1 :source:absorbed_beam:signal
	Wave/T signal=:source:absorbed_beam:signal
	signal="1"
	Wave intens=:source:absorbed_beam:data
//	Note/NOCR intens, "@signal=1"				/// Attribute
	NewDataFolder root:ToConvert:entry:sample
	String/G root:ToConvert:entry:sample:name="Banana popsicle"
	NewDataFolder root:ToConvert:entry:monitor
	String/G root:ToConvert:entry:monitor:mode="monitor"
	Variable/G root:ToConvert:entry:monitor:preset=5
	Make/n=5 root:ToConvert:entry:monitor:data
	NewDataFolder root:ToConvert:entry:data
	
	NewPath/O hdfpath, impath
//	STRUCT HDF5DatatypeInfo dti	// Defined in HDF5 Browser.ipf.
//	InitHDF5DatatypeInfo(dti)	// Initialize structure.
	HDF5CreateFile/O/P=hdfpath fileid as s_folder+".h5"
	HDF5CreateGroup fileid, "entry", entryid
	
	HDF5SaveGroup/O/R root:ToConvert:entry, fileid, "entry"
	HDF5CreateLink fileid, "/entry/source/monochromator/energy", fileid, "/entry/data/energy"
	HDF5CreateLink fileid, "/entry/source/absorbed_beam/data", fileid, "/entry/data/absorbed_beam"
//	HDF5TypeInfo(fileid, "entry/source/absorbed_beam/data", "@signal=1", "", 0, dti)
//	
//	HDF5CreateGroup fileid, "entry//title", titleid
	
	HDF5CloseFile fileid
//	Variable nooffiless=CountObjects(origfolder,4)
//	Variable counter=0
//	String s_file
//	String fullpath
//	do
//		s_image=GetINdexedObjName(imgfolder,4,counter)
//		fullpath=imgfolder+s_image+":"+s_image+type
//		imgplot(fullpath)
//		counter+=1
//	while(counter<noofimgs)
	SetDataFolder saveDF
End

Function CreateNXsample()

End

Function CreateNXinstrument(instrname)
	String instrname
// Creates an NXinstrument at the current datafolder location
// with the name "instrname"
	DFREF saveDF = GetDataFolderDFR()
	NewDataFolder/S $(instrname+"_NXinstrument")
	CreateNXsource("IVID")
	CreateNXmonochromator("VLS")
	CreateNXdetector("incoming_beam","izero", "Izero")
//	CreateNXabsorbed_beam()
	
	SetDataFolder saveDF
End

Function CreateNXsource(sourcename)
	String sourcename
	//
	DFREF saveDF = GetDataFolderDFR()
	NewDataFolder/S $(sourcename+"_NXsource")
	String/G type=""
	String/G name=""
	String/G probe="x-ray"
	
	SetDataFolder saveDF
End

Function CreateNXmonochromator(mononame)
	String mononame
	//
	DFREF saveDF = GetDataFolderDFR()
	NewDataFolder/S $(mononame+"_NXmonochromator")
	ControlInfo/W=NeXusConverterPanel popup_origfolder
	String s_folder = S_Value, origfolder
	ControlInfo/W=NeXusConverterPanel popup_energy
	Wave energy=$("root:AXIS:Original:"+s_folder+":'"+S_Value+"'")
	Duplicate energy :energy
	SetDataFolder saveDF
End

Function CreateNXdetector(detector, detname, signame)
	String detector, detname, signame
	//detname can be one of: energy, izero, det1, det2, det3, det4
	DFREF saveDF = GetDataFolderDFR()
	NewDataFolder/S $(signame+"_NXdetector")
	ControlInfo/W=NeXusConverterPanel popup_origfolder
	String s_folder = S_Value, origfolder
	ControlInfo/W=NeXusConverterPanel $("popup_"+detname)
	SetDataFolder saveDF
End