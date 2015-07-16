--strcut cannot put into dictionary (cannot convert to system.obj)
-- structure for presetlist item
--struct preset_struct (Meshlist=#(), Savepath="",Filename="")
-- dictionaty for presetlist 
global preset_dic=dotNetObject "System.Collections.Hashtable"
global presetholder=getNodeByName "PresetHolder"
global preset_item=#("None")
global selectionsets_item=#("") 

--print presetfolder
function createdummy=(
	presetholder=getNodeByName "PresetHolder"
	if presetholder==undefined then(
		print "123"
		presetholder=Dummy pos: [0,0,0] name:"PresetHolder" scale:[5,5,5]
		--hide and freeze the PresetHolder
		hide presetholder
		freeze presetholder
		--write data to dummy String
		Preset_block = attributes presetData(
			Parameters main rollout:params(
				--define the new attributes to the string
				Preset_Handle Type: #string UI:PresetXML Default:"<PresetXML></PresetXML>"
			)
			Rollout Params "Custom Attributes"(
				--define the UI interface
				editText PresetXML "" Align: #Center readOnly: true 
			)
		)
		CustAttributes.add presetholder Preset_block
	)
)

function loadDatafromXML=(
	strxml=presetholder.Preset_Handle
	print strxml
	xmlDoc = dotNetObject "System.Xml.XmlDocument"
	--load xml file from string store on the scene obj
	xmlDoc.loadXml(strxml)
	docElement = xmlDoc.DocumentElement
	preset_Node=docElement.getElementsByTagName "Preset"
	--go in to each node
	for i=0 to preset_Node.count-1 do(
		tempitem=#()
		preset_Name=(preset_Node.ItemOf(i)).getAttribute "PresetName"
		append preset_item preset_Name
		filename_Node=preset_Node.ItemOf[i].getElementsByTagName "FileName"
		--filename_node list have on child only
		file_Name=(filename_Node.ItemOf[0]).getAttribute "FileName"
		savepath_Node=preset_Node.ItemOf[i].getElementsByTagName "SavePath"
		--savepath_node list have on child only
		save_Path=(savepath_Node.ItemOf[0]).getAttribute "SavePath"
		item_Node=(preset_Node.ItemOf[i]).getElementsByTagName "ItemName"
		meshlist=(for i=0 to item_Node.count-1 collect(
			item_Node.ItemOf[i].getAttribute "ItemName"
		))
		append tempitem file_Name
		append tempitem save_Path
		append tempitem meshlist
		preset_dic.Add preset_Name tempitem
		--print preset_dic.item[preset_Name]
	)
)

function selectitemonlist source:undefined item_index:undefined=(
	clearSelection()
	objlist=#()
	for i in item_index do (
		obj=getNodeByName source[i]
		if obj!=undefined then(
		append objlist obj
		)
		else(
			messageBox("cannot find the object"+source[i])
		)
	)
	select objlist

)


function additemtolist source: undefined=(
	if selection.count>0 then (
		for i in selection do (
			added=appendIfUnique source i.name
			if added==false then(
				messageBox(i.name+ "  exsits")
			)
		)
		return source
	)
	else (
		return source
	)
)

function removeitemfromlist source: undefined item_index: undefined=(
		if source.count>0 and item_index.numberset>0 then(
			item_arr=item_index as array
			--remove item from array
			i=item_arr.count
			while (i>0) do (
				deleteItem source item_arr[i]
				i=i-1
			)
		)
		return source
)

function saveDataOnXML source:undefined=(
	fname=getSaveFileName caption:"Save XML File:" types:"XML files (*.xml)|*.xml"
	if fname !=undefined then(
		xmlDoc = dotNetObject "System.Xml.XmlDocument"
		xmlRoot = xmlDoc.CreateElement ("SelectionSets")
		xmlDoc.appendChild xmlRoot
		for i in source do (
			ObjNode=xmlDoc.CreateElement "Attribute"
			ObjNode.SetAttribute "ItemName" i
			xmlRoot.appendChild ObjNode
		)
		xmlDoc.save(fname)

	)
)

function readDataOnXML source:undefined=(
	fname=getOpenFileName caption:"Open XML File" types:"XML file(*.xml)|*.xml"
	if fname !=undefined then(
		xmlDoc = dotNetObject "System.Xml.XmlDocument"
		xmlDoc.load(fname)
		docElement=xmlDoc.DocumentElement
		NodeList=docElement.getElementsByTagName "Attribute"
		temp = (for i=0 to (NodeList.count-1) collect (NodeList.item i).getAttribute "ItemName")
		for i in temp do (
			exsits=appendIfUnique source i
			--print exsits
			if exsits==false then (
				messageBox(i+ "  exsits")
			)
		)
		return source
	)
)
function UpdatePresetOnXML=(
	-- UpdatePresetOnXML--
	xmlDoc = dotNetObject "System.Xml.XmlDocument"
	xmlRoot = xmlDoc.CreateElement ("PresetXML")
	xmlDoc.appendChild xmlRoot
	it=preset_dic.GetEnumerator()
	while it.MoveNext() do(
		print it.current.key 
		print it.current.value
		preset_Node=xmlDoc.CreateElement "Preset"
		preset_Node.SetAttribute "PresetName" it.current.key
		xmlRoot.appendChild preset_node
		filename_Node=xmlDoc.CreateElement "FileName"
		filename_Node.SetAttribute "FileName" it.current.value[1]
		preset_Node.appendChild filename_Node
		savepath_Node=xmlDoc.CreateElement "SavePath"
		savepath_Node.SetAttribute "SavePath" it.current.value[2]
		preset_Node.appendChild savepath_Node
		for i in it.current.value[3] do (
			mesh_Node=xmlDoc.CreateElement "ItemName"
			mesh_Node.SetAttribute "ItemName" i  
			preset_Node.appendChild mesh_Node
		)
	)
	--return string type
	--xmlDoc.save("C:\\Users\\hzwangtenghao\\Desktop\\1\\test2.xml")
	return xmlDoc.OuterXml
)



function AddPresetList source:undefined meshlist:undefined savepath:undefined filename:undefined preset_name:undefined=(
	if maxFilePath !=undefined then(
		if preset_name.count>0 then(
			exists=appendIfUnique source preset_name
			if exists==false then (
				messageBox("Preset name exists")
				return source
			)
			tempitem=#(filename, savepath, meshlist)
			preset_dic.Add preset_name tempitem
			presetholder.Preset_Handle=UpdatePresetOnXML()
			return source
		)
		else(
			messageBox("Preset name cannot be empty")
			return source
		)
	)
	else(
		messageBox("Please save file first")
	)
) 

function RemovePresetList source:undefined selection:undefined selected:undefined=(
	if selected != "None" and selected!= undefined then(
		deleteItem source selection
		--remove pair in preset_dic
		preset_dic.Remove selected
		presetholder.Preset_Handle=UpdatePresetOnXML()
		return source
	)
	else(
		return source
	)
)

function RenamePresetList source:undefined selection:undefined selected:undefined presetname:undefined=(
	if selected !="None" and (findItem source presetname)==0 then(
		print presetname
		source[selection]=presetname
		--change the key of dic
		preset_dic.Add presetname preset_dic.item[selected]
		preset_dic.Remove selected
		presetholder.Preset_Handle=UpdatePresetOnXML()
		return source

	)
	else(
		messageBox("Preset name exsits")
		return source
	)
	
)

function exportFBX output:undefined meshlist:undefined=(
	objlist=#()
	clearSelection()
	for i in meshlist do (
		obj=getNodeByName(i)
		append objlist obj
	)
	select objlist
	-- default export animation
	FbxExporterSetParam "Animation" True
	FbxExporterSetParam "BakeAnimation" True
	FbxExporterSetParam "BakeResampleAnimation" True
	--mesh export options
	FbxExporterSetParam "Skin" True
	FbxExporterSetParam "SmoothingGroups" True
	--use 2011 file version
	FbxExporterSetparam "FileVersion" "FBX201100"
	FbxExporterSetParam "UpAxis" "Y"

	exportFile output #noPrompt selectedOnly:True using:FBXEXP

)

function systemunitsetup index:undefined=(
	case index of (
		1: units.SystemType=#Inches
		2: units.SystemType=#Feet
		3: units.SystemType=#Miles
		4: units.SystemType=#Millimeters
		5: units.SystemType=#Centimeters
		6: units.SystemType=#Meters
		7: units.SystemType=#Kilometers
	)
)



rollout FBXrollout "FBX Export Tool" width: 328 height: 620
(
	editText fileName "Filename" pos:[8,8] width:312 height:16
	label exportPathLabel "Export Path:" pos:[16,40] width:200 height:20 
	editText expPathTxt "" text:"C:\\Program Files\\Autodesk\\3ds Max 2012" pos:[8,60] fieldWidth: 216 height:18
	button browseBtn "Browse" pos:[232,56] width:88 height:24
	--selection sets
	GroupBox grpset "Selection" pos:[8,88] width:312 height:220
	checkBox SelectionSetsCheck "Using Selection Sets:" pos:[16,119] width:132 checked:true
	dropDownlist selectionsets pos:[150,116] items:selectionsets_item width: 150 height: 41
	checkBox NameSpaceCheck "Using Name Space" pos:[16,139] width:132 checked:true
	CheckBox SceneSelcetionCheck "Using Scene Selection" pos:[16,159] width:132 checked:true
	--MultiListBox meshExpLB "Mesh List:" pos:[16,110]  width:296 height:9
	--button addmeshBtn "Add Selected Mesh" pos:[20,255] width:130 height:20
	--button removemeshBtn "Remove Selected Mesh" pos:[180,255] width:130 height:20
	--button importxmlBtn "Import File" pos:[20,280] width:130 height:20
	button exportxmlBtn "Export Selection" pos:[180,280] width:130 height:20
	--Preset
	dropDownlist presetList "Export Setting Preset:" pos:[16,350] items:preset_item width:200 height:41
	editText presetname "New Presetname" pos:[20,400] width:280 height:15 text: "Put the preset name here..."
	button addpreset "Add" pos: [40,430] width: 88 height: 24 tooltip: "Save above setting to the preset"
	button renamepreset "Rename" pos: [170,430] width:88 height:24 tooltip: "Rename the current preset"
	button removepreset "Remove" pos: [224,366] width: 88 height:24 tooltip: "Remove the current  preset"
	groupBox grpExport "Preset" pos:[8,328] width:312 height:160
	groupBox grpUnitSetup "System Unit Setup:" pos:[8,490] width:312 height:60
	label UnitSetupLabel "1 Unit = 1.0" pos:[70,515] 
	dropDownlist UnitList "" pos:[138,512] width:150 height:41 items:#("Inches","Feet","Miles","Millimeters","Centimeters","Meters","Kilometers")
	button expBtn "Export File" pos:[16,560] width:296 height:30

	on FBXrollout open do (
		--set the default unit to centimeter when initialize the gui
		UnitList.selection=5
		systemunitsetup index:5 
	)

	on meshEXPLB selectionEnd do(
		selectitemonlist source:meshExpLB.items item_index:meshExpLB.selection
	)
	on addmeshBtn pressed do(
		meshExpLB.items=additemtolist source:meshExpLB.items
	)
	on removemeshBtn pressed do(
		--return bitarray
		meshExpLB.items=removeitemfromlist source:meshExpLB.items item_index:meshExpLB.selection
	)
	on importxmlBtn pressed do(
		meshExpLB.items=readDataOnXML source:meshExpLB.items
	)
	on exportxmlBtn pressed do (
		saveDataOnXML source: meshExpLB.items
	)
	on browseBtn pressed do(
		p=getSavePath caption:"Defined Output Path" initialDir:expPathTxt.text
			if p!=undefined then (
				expPathTxt.text=p
			)
	)

	on addpreset pressed do (
		presetList.items=AddPresetList source: presetList.items meshlist:meshExpLB.items savepath:expPathTxt.text filename:fileName.text preset_name:presetname.text
	)

	on presetList selected index do(
		preset_name=presetlist.items[index]
		if preset_name != "None" then(
			tempitem=preset_dic.item[preset_name]
			print tempitem
			--unpack item #(filename, savepath, meshlist)
			fileName.text=tempitem[1]
			expPathTxt.text=tempitem[2]
			meshExpLB.items=tempitem[3]
		)
	)

	on Removepreset pressed do (
		presetlist.items=RemovePresetList source: presetlist.items selection:presetlist.selection selected: presetlist.selected
	)

	on Renamepreset pressed do (
		presetlist.items=RenamePresetList source:presetlist.items selection:presetlist.selection selected:presetlist.selected presetname:presetname.text

	)
	on expBtn pressed do (
		outputpath= expPathTxt.text + "\\" + filename.text
		print outputpath
		exportFBX output: outputpath meshlist: meshExpLB.items
	)

	on UnitList selected index do(
		systemunitsetup index:index
	)

)

createdummy()
loadDatafromXML()	

utility LT_FBX_Exporter "LT_FBX_Exporter"
(
	local expFloater

	button expBtn "FBX_Exporter" width:120;
	
	on expBtn pressed do (
		-- if the floater is open close it and reopen a new one 
		try (closeRolloutFloater expFloater) catch()
		expFloater=newRolloutFloater "FbxExporter" 336 630
		addRollout FBXrollout expFloater
	)
	

)