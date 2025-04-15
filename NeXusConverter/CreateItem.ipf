#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

Function CreateItem(header_json,jsonpath)
	String header_json
	String jsonpath
	Variable counter,jsonid
	String newjsonpath
	Make/T/FREE sublevelkeys
	jsonid = JSON_Parse(header_json)
	JSONXOP_GetKeys jsonid,jsonpath,sublevelkeys
	Variable nkeys=numpnts(sublevelkeys)
	counter=0
	if(nkeys>0)
		do
			newjsonpath=jsonpath+"/"+sublevelkeys[counter]
			Switch (JSON_GetType(jsonid,newjsonpath))
				case 0:	//Object
					NewDataFolder/S $(RemoveBadCharacters(sublevelkeys[counter]))
					CreateItem(header_json,newjsonpath) //+"/"+sublevelkeys[counter])
					SetDataFolder ::
					break
				case 1:	//Array
					Variable k=0,arraysize = JSON_GetArraySize(jsonid,newjsonpath)
					String str, newfolder
					Make/T/N=(arraysize) twave
//					JSONXOP_GetValue/T/WAVE=twave/FREE jsonID, newjsonpath
					if (arraysize>0)
						do
       						sprintf str, "%s/%d", newjsonpath,k
       						sprintf newfolder, "%s_%d", sublevelkeys[counter],k
       						if(JSON_GetType(jsonId,str)==0)
       							print "tjo"
       							NewDataFolder/S $(RemoveBadCharacters(newfolder))
       							CreateItem(header_json,str)
       							SetDataFolder ::
       						else
	       						JSONXOP_GetValue/T jsonId, str
//							sprintf str, "%s/%d", newjsonpath,k
//							JSONXOP_GetValue/WAVE=twave jsonId, str
	       						twave[k]=S_Value
   							endif
   	    	 				k += 1
   		 				while (k < arraysize)
   		 			endif
    				Rename twave,$(RemoveBadCharacters(sublevelkeys[counter]))
					break
				case 2:	//Variable
					Variable/G vtmp
					vtmp=JSON_GetVariable(jsonid,newjsonpath)
					Rename vtmp,$(RemoveBadCharacters(sublevelkeys[counter]))
					break
				case 3:	//String
					String/G stmp
					stmp = JSON_GetString(jsonid,newjsonpath)
					if(cmpstr(sublevelkeys[counter],"date",0)==0)
						Rename stmp,$(RemoveBadCharacters(sublevelkeys[counter]+"x"))
					else
						Rename stmp,$(RemoveBadCharacters(sublevelkeys[counter]))
					endif
					break
				case 4:	//Boolean
//					print "boolean "+num2str(counter)
					Variable/G vtmp
//					print JSON_GetString(jsonid,newjsonpath)
					JSONXOP_GetValue/V jsonID, newjsonpath
					vtmp=V_value
					Rename vtmp,$(RemoveBadCharacters(sublevelkeys[counter]))
					break
			EndSwitch
			counter+=1
		while(counter<nkeys)
	endif
	JSON_Release(jsonid)
//	print "exiting CreateItem"
	Return 0
End

Function/S RemoveBadCharacters(word)
	String word
	word = ReplaceString("~",word,"_")
	word = ReplaceString("-",word,"_")
	word = ReplaceString(" ",word,"_")
	word = ReplaceString("(",word,"_")
	word = ReplaceString(")",word,"_")
	Return word
End