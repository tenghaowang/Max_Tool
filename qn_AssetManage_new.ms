--define custom structures
struct animExpOptions (isExport = True, skelSet = "", animStart = 0, animEnd = 30)
struct meshExpOptions (objList = #(), texExport = True, texPath = "", texSource = "", texReplace = "")
global resourceDirList = #()
--get a list of all objects 
function GetAllChildren root:undefined = 
(
	bone_buffer = #();
	bone_list = #();
	child_list = #();

	append bone_buffer root;
	append bone_list root;	
	while bone_buffer.count>0 do
	(
		--get the child of the current buffer, add children to the child buffer and the bone list
		for i in bone_buffer do
		(
			temp_bone = i;
			temp_child = i.children;
			if temp_child.count > 0 do
			(
				for j in temp_child do
				(
					append child_list j;
					append bone_list j;
				)
			)
		)
	
		bone_buffer = #(); 
		bone_buffer = child_list;
		child_list = #();
	)

	return bone_list;
)

--this function removes existing prefix (if exist), and add indicated new one
--note: no ":" is allowed in original names
function BatchPrefix prefix:undefined selected:false =
(
	if selected == false then
	(
		obj_list = GetAllChildren root:selection[1];
	)
	else
	(
		obj_list = selection;
	)
	name_list = #();
	for i in obj_list do
	(
		objName = i.name;
		prefixArray = filterString objName ":";
		if prefix != undefined then
		(
			i.name = prefix + ":" + prefixArray[prefixArray.count];
		)
		else
		(
			i.name = prefixArray[prefixArray.count];
		)
		append name_list i.name;
	)
	return name_list;
)

--this creates constraints for two set of bones
--note that the reference bones
function ConstraintBones refRoot:undefined targetRoot:undefined isPos:true isRot:true isOff:false =
(
	refList = GetAllChildren root:refRoot;
	targetList = GetAllChildren root:targetRoot;
	
	for i in targetList do
	(
		for j in refList do
		(
			refNameArray = filterString j.name ":";
			refName = refNameArray[refNameArray.count]; --get the last element
			
			targetNameArray = filterString i.name ":";
			targetName = targetNameArray[targetNameArray.count]; --get the last element
			
			--create constraint if the are the same
			if refName == targetName do
			(
				print (i.name + " <constrained to> " + j.name);
				if (isPos == true) do (
					pCon = Position_Constraint();
					if (isOff == true) do (
						pCon.relative = true;
					)
					i.position.controller = pCon;
					pCon.appendTarget j 100.0;
				)
				
				if (isRot == true) do (
					rCon = Orientation_Constraint();
					if (isOff == true) do (
						rCon.relative = true;
					)
					i.rotation.controller = rCon;
					rCon.appendTarget j 100.0;
				)
			)
		)
	)
)

--duplicate a bone hierarchy
function CreateSkelProxy root:undefined psize:1.0 = (
	--get the original bone list
	boneList = #()
	refNameList = #()
	if (selection[1] != undefined) then (
		refList = GetAllChildren root:selection[1]
	)
	else (
		return undefined
	)
	for obj in refList do (
		append refNameList obj.name
	)
	--add prefix to the original bone set
	BatchPrefix prefix:"Ref" selected:false
	--create bones
	for i = 1 to refList.count do (
		pnt = Point()
		pnt.size = psize
		pnt.cross = false
		pnt.box = true
		pnt.transform = refList[i].transform
		pnt.scale = [1,1,1]
		pnt.name = refNameList[i]
		append boneList pnt
	)
	--go through the bone list and set its parent according to original bone set
	for i= 1 to boneList.count do (
		pRef = refList[i].parent
		if pRef != undefined do (
			spName = filterString pRef.name ":"
			boneList[i].parent = getNodeByName(spName[spName.count])
		)
	)
	--constrian the ref bone to the source
	ConstraintBones refRoot:refList[1] targetRoot:boneList[1] isPos:true isRot:true isOff:false
)

--only bake to integer frames
function BakeAnimation start:0 end:30 step:1 =
(
	if selection.count == 0 then
		return 1;
	else
	(
		--count how many frames that will be stored;
		frameCount = 1+ (((end-start+1)/step) as integer);
		--go through each object and get its translation matrix
		objList = #();
		posList = #()
		rotList = #()
		timeList = #();
		for i in selection do
		(
			append objList i;
			tmpPos = #();
			tmpRot = #();
			tmpTimeList = #();
			for j = 1 to frameCount do
			(
				at time (start + (j-1) * step);
				append tmpPos i.inode.posInParent;
				local tr = eulerAngles i.inode.rotInParent.x i.inode.rotInParent.y i.inode.rotInParent.z;
				append tmpRot tr;
				append tmpTimeList  (start + (j-1) * step);
				if j == frameCount do
				(
					if (start + (j-1) * step) < end do
					(
						at time end
						append tmpPos i.inode.posInParent;
						append tmpRot tr;
						append tmpTimeList  end;
					)
				)
			)
			append posList tmpPos;
			append rotList tmpRot;
			append timeList tmpTimeList;
		)
		
		--apply the transform matrix array and set keys
		--animButtonState = true;
		for i=1 to objList.count do
		(
			--max select none;
			--select objList[i];
			--create default controllers for the current node
			prsCon = prs();
			objList[i].transform.controller = prs();
			pCon = bezier_position();
			objList[i].position.controller = pCon;
			rCon = bezier_rotation();
			objList[i].rotation.controller = rCon;
			--go through timeline and add keys
			for j=1 to timeList[i].count do (
				addNewKey objList[i].position.controller timeList[i][j]
				addNewKey objList[i].rotation.controller timeList[i][j]
			)
			--go through timeline and set keys
			for j = 1 to posList[i].count do
			(
				addNewKey objList[i].position.controller timeList[i][j]
				addNewKey objList[i].rotation.controller timeList[i][j]
				pkid = getKeyIndex objList[i].position.controller timeList[i][j]
				rkid = getKeyIndex objList[i].rotation.controller timeList[i][j]
				objList[i].position.controller.keys[pkid].value = posList[i][j] 
				objList[i].rotation.controller.keys[rkid].value = rotList[i][j] as quat
			)
		)
	)
)

--rename objects according to their diffuse texture name
function RenameByDiffuseMap = 
(
	for obj in selection do (
		if obj.material != undefined then (
			fname = undefined
			if hasProperty obj.material "diffuseMap" then (
				fname = obj.material.diffuseMap.filename
			)
			if hasProperty obj.material "materialList" then (
				fname = obj.material.materialList[1].diffuseMap.filename
			)
			
			if fname != undefined then (
				fname = filenameFromPath fname
				fname = getFilenameFile fname
				if findString obj.name "body" != undefined then (
					obj.name = fname + "_Body"
				)
				else if findString obj.name "hair" != undefined then (
					if findString fname "head" != undefined then (
						obj.name = (substituteString fname "head" "heead")  + "_Hair"
					)
					else (
						obj.name = fname + "_Hair"
					)
				)
				else if findString obj.name "head" != undefined then (
					obj.name = fname + "_Head"
				)
				else if findString obj.name "face" != undefined then (
					obj.name = fname + "_Face"
				)
				else if findString obj.name "shoe" != undefined then (
					obj.name = fname + "_Shoe"
				)
				else (
					obj.name = fname + "_Node"
				)
			)
			else (
				print(obj.name + " don't have valid texture.")
			)
		)
		else (
			print(obj.name + " don't have valid material.")
		)
	)
)

--get object list from keywords
function GetObjectListByKeyword keyword:undefined = (
	objList = #()
	append objList "None"
	for obj in rootScene.world.children do (
		if findString obj.name keyword != undefined then (
			append objList obj.name
		)
	)
	return objList
)

--set up a solo display within the given list
function SoloObjectDisplay list:undefined selected:undefined except:undefined = (
	for oname in list do (
		obj = getNodeByName(oname)
		if obj != undefined do (
			if oname == selected then (
				obj.isHidden = false
			)
			else (
				if oname != except then (
					obj.isHidden = true
				)
				else (
					obj.isHidden = false
				)
			)
		)
	)
)

--create root node
--seems not needed
function CreateAnimRoot = (
	--get root node in skeleton set
)

--export current selection set as text file
function ExportSkelSet setName:undefined = (
	fName = getSaveFileName caption:"选择保存位置" types:"Text files(*.txt)|*.txt"
	if fName != undefined do (
		if doesFileExist fName == true then (
			fs = openFile fName mode:"w"
		)
		else (
			fs = createFile fName
		)
		eSet = selectionSets[setName]
		local sNames
		sNames = "qn_SkelSet|" + setName
		for i = 1 to eSet.count do (
			sNames = sNames + "|" + eSet[i].name
		)
		print sNames to:fs
		flush fs
		close fs
	)
)
--load a selection set from a text file
function ImportSkelSet fName:undefined = (
	if fName == undefined do (
		fName = getOpenFileName caption:"选择要导入的文件" types:"Text files(*.txt)|*.txt"
	)
	if fName != undefined do (
		fs = openFile fName mode:"r"
		sl = readLine fs
		sl = subString sl 2 (sl.count-2)
		sList = filterString sl "|"
		oList = #()
		bList = #()
		if sList[1] != "qn_SkelSet" then (
			messagebox "此文件不是骨骼选择集"
		)
		else (
			clearSelection()
			for i = 3 to sList.count do (
				if getNodeByName(sList[i]) != undefined then (
					append bList (getNodeByName(sList[i]))
				)
				else (
					print ("骨骼 " + sList[i] + " 不存在于此场景中")
				)
			)
			select bList
			selectionSets[sList[2]] = selection
		)
		return sList[2]
	)
)

--update the selection sets list
function UpdateSetDList = (
	local sItems = #()
	append sItems ("None")
	for i = 1 to selectionSets.count do (
		append sItems (getNamedSelSetName i)
	)
	return sItems
)

--add current selection to object list
function AddNameToArray source:undefined = (
	if selection.count>0 then (
		for i in selection do (
			append source i.name
		)
		return source
	)
	else (
		return source
	)
)

--remove selected item from object list
function RemoveNameFromArray source:undefined item:undefined = (
	if source.count > 0 then (
		rid = -1
		for i =1 to source.count do (
			if source[i] == item do (
				rid = i
			)
		)
		if rid != -1 then (
			deleteItem source rid
			return source
		)
		else (
			return source
		)
	)
	else (
		return source
	)
)

--make modifier unique to prevent performance issues
function MakeTopModUnique = (
	for i in selection do (
		if InstanceMgr.CanMakeModifiersUnique #(i) #(i.modifiers[1]) != False do (
			InstanceMgr.MakeModifiersUnique #(i) #(i.modifiers[1]) #prompt
		)
	)
)

--the function to write fbx file to destination
function ExportFBXFile outPath:"" outFileName:"" animOptions:undefined meshOptions:undefined = (
	--select all the objects that need to be exported
	objList = #()
	clearSelection()
	--select meshes
	for i in meshOptions.objList do (
		obj = getNodeByName(i)
		append objList obj
	)
	--select skeletons if there is
	if animOptions.skelSet != "None" do (
		bSet = selectionSets[animOptions.skelSet]
		if (bSet!=undefined) do (
			for i in bSet do (
				append objList i
			)
		)
	)
	select objList
	units.SystemType = #centimeters --set system unit to cm to prevent unity from doing wrong things
	--set fbx export parameters
	--animation options if animation is going to be exported
	if animOptions.isExport == True then (
		FbxExporterSetParam "Animation" True
		FbxExporterSetParam "BakeAnimation" True
		FbxExporterSetParam "BakeFrameStart" animOptions.animStart
		FbxExporterSetParam "BakeFrameEnd" animOptions.animEnd
		FbxExporterSetParam "BakeResampleAnimation" True
	)
	else (
		FbxExporterSetParam "Animation" False
	)
	
	--mesh export options
	FbxExporterSetParam "Skin" True
	FbxExporterSetParam "SmoothingGroups" True
	--use oldest file version
	FbxExporterSetparam "FileVersion" "FBX200611"
	FbxExporterSetParam "UpAxis" "Y"
	
	exportFile (outPath + "\\" + outFileName) #noPrompt selectedOnly:True using:FBXEXP
	print ("输出至: " + outPath + "\\" + outFileName)
	--copy texture files
	if meshOptions.texExport == True do (
		texFileList = #()
		for i in meshOptions.objList do (
			obj = getNodeByName(i)
			if obj.material != undefined then (
				fname = undefined
				if hasProperty obj.material "diffuseMap" then (
					fname = obj.material.diffuseMap.filename
				)
				if hasProperty obj.material "materialList" then (
					fname = obj.material.materialList[1].diffuseMap.filename
				)
			
				if findString fname meshOptions.texSource != undefined then (
					append texFileList (substituteString fname meshOptions.texSource meshOptions.texReplace)
				)
				else (
					append texFileList fname
				)
			)
		)

		for i in texFileList do (
			print i
			if meshOptions.texPath == undefined then (
				makeDir (outPath + "\\Texture")
				cs = copyFile i (outPath +"\\Texture\\" + (filenameFromPath i))
				print (outPath +"\\Texture\\" + (filenameFromPath i))
				if cs == True do (
					print ("Copied: " + (filenameFromPath i))
				)
			)
			else (
				cs = copyFile i (meshOptions.texPath + "\\" + (filenameFromPath i))
				print (meshOptions.texPath + "\\" + (filenameFromPath i))
				if cs == True do (
					print ("Copied: " + (filenameFromPath i))
				)
			)
		)
	)
)

--add a bone pair to the list
function AddBonePair inputList:undefined = (
	if (selection.count >= 2 ) then (
		for i = 1 to selection.Count-1 do (
			append inputList (selection[i].name + ">" + selection[selection.Count].name)
		)
		return inputList
	)
	else (
		print ("只能选择两个物体建立替换关系。")
		return inputList
	)
)

--remove a bone pair from the list
function RemoveBonePair input:undefined inputList:undefined = (
	local ii = findItem inputList input
	if ii != 0 then (
		deleteItem inputList ii
		return inputList
	)
	else (
		return inputList
	)
)

--export current bone pair list to a text file
function ExportBonePairs inputList:undefined = (
	fName = getSaveFileName caption:"选择保存位置" types:"Text files(*.txt)|*.txt"
	if fName != undefined do (
		if doesFileExist fName == true then (
			fs = openFile fName mode:"w"
		)
		else (
			fs = createFile fName
		)
		local sNames
		sNames = "qn_BonePair"
		for i = 1 to inputList.count do (
			sNames = sNames + "|" + inputList[i]
		)
		print sNames to:fs
		flush fs
		close fs
	)
)

--load a selection set from a text file
function ImportBonePairs inputList:undefined = (
	fName = getOpenFileName caption:"选择要导入的文件" types:"Text files(*.txt)|*.txt"
	if fName != undefined do (
		fs = openFile fName mode:"r"
		sl = readLine fs
		sl = subString sl 2 (sl.count-2)
		sList = filterString sl "|"
		bList = #()
		if (sList[1] != "qn_BonePair") then (
			print "此文件不是骨骼关系定义"
			return inputList
		)
		else (
			for i= 2 to sList.count do (
				append bList sList[i]
			)
			return bList
		)
	)
	return inputList
)

--replace skin weights
function ReplaceSkinWeights inputList:undefined = (
	setCommandPanelTaskMode mode:#modify
	objList = #()
	for o in selection do (
		append objList o
	)
	clearSelection()
	for obj in objList do (
		sk = obj.modifiers[1]
		if sk != undefined do (
			if classOf sk == Skin do (
				ReplaceWeight obj:obj inputList:inputList
			)
		)
	)
	for obj in objList do (
		selectMore obj
	)
)

function ReplaceWeight obj:undefined inputList:undefined = (
	select obj
	sk = selection[1].modifiers[1]
	boneNameList = #()
	bc = skinOps.GetNumberBones sk
	for i = 1 to bc do (
		bn = skinOps.GetBoneName sk i 0
		append boneNameList bn
	)
	vc = skinOps.GetNumberVertices sk
	for i = 1 to vc do (
		ic = skinOps.GetVertexWeightCount sk i
		bl = #()
		wl = #()
		--build an original vertex weight list for a vertex
		for j = 1 to ic do (
			append bl (skinOps.GetVertexWeightBoneID sk i j)
			append wl (skinOps.GetVertexWeight sk i j)
		)
		--replace vertex weight list when necessary
		for j = 1 to ic do (
			for k in inputList do (
				pr = filterString k ">"
				bid = findItem boneNameList pr[1]
				if bl[j] == bid do (
					nn = findItem boneNameList pr[2]
					if nn != 0 do (
						bl[j] = nn
					)
				)
			)
		)
		--create final vertex weight list to set on the vertices
		bfl = #()
		wfl = #()
		for j = 1 to ic do (
			bfi = findItem bfl bl[j]
			if bfi == 0 then (
				append bfl bl[j]
				append wfl wl[j]
			)
			else (
				wfl[bfi] += wl[j]
			)
		)
		--set the vertex weight
		skinOps.ReplaceVertexWeights sk i bfl wfl
	)
)

--remove unused skin weights
function RemoveUnusedBones = (
	setCommandPanelTaskMode mode:#modify
	if selection.Count < 1 then (
		print "没有选择任何物体"
	)
	else (
		objList = #()
		for o in selection do (
			append objList o
		)
		clearSelection()
		for obj in objList do (
			sk = obj.modifiers[1]
			select obj
			if sk != undefined do (
				if classOf sk == Skin do (
					RemoveBones obj:obj
				)
			)
		)
	)
)

function RemoveBones obj:undefined = (
	sk = obj.modifiers[1]
	boneNameList = #()
	bc = skinOps.GetNumberBones sk
	oldCount = bc
	for i = 1 to bc do (
		bn = skinOps.GetBoneName sk i 0
		append boneNameList bn
	)
	sk = obj.modifiers[1]
	bCount = skinOps.GetNumberBones sk
	vCount = skinOps.GetNumberVertices sk
	usedBoneList = #()
	usedBoneNameList = #()
	for i= 1 to vCount do (
		n = skinOps.GetVertexWeightCount sk i
		for j = 1 to n do (
			bn = skinOps.GetVertexWeightBoneID sk i j
			fi = findItem usedBoneList bn
			if fi == 0 do (
				append usedBoneList bn
				append usedBoneNameList (skinOps.GetBoneName sk bn 0)
			)
		)
	)
	--generate unused bone name list
	unusedBones = #()
	for i in boneNameList do (
		found = false
		for j in usedBoneNameList do (
			if i == j do (
				found = true
			)
		)
		if found == false do (
			append unusedBones i
		)
	)
	--for each unused bones, go through the bone list and find id, remove from the system
	for i in unusedBones do (
		ri = -1
		bc = skinOps.GetNumberBones sk
		for j = 1 to bc do (
			bn = skinOps.GetBoneName sk j 0
			if bn == i do (
				ri = j
			)
		)
		if ri != -1 do (
			skinOps.RemoveBone sk ri
			--print i
		)
	)
	nbc = skinOps.GetNumberBones sk
	print("物体 " + obj.name + " 已从 " + oldCount as string + " 根骨骼减少至 " + nbc as string + " 根骨骼. " )
)

function ResetAndFlipNormal = (
	for i in selection do (
		minusScale = false
		if i.scale.x<0 do (
			minusScale = true
		)
		if i.scale.y<0 do (
			minusScale = true
		)
		if i.scale.z<0 do (
			minusScale = true
		)
		ResetXForm i
		if minusScale == true do (
			addModifier i (normalModifier())
			i.modifiers[1].flip = true
		)
		collapseStack i
	)
)

function ResetSkinXForm = (
	--save skin envelope, reset transform and re-import the envelope
	setCommandPanelTaskMode mode:#modify
	--obj = selection[1]
	--if selection.count>1 do (
		--messagebox ("一次只能处理一个物体，本次操作只会作用于第一个选择的物体")
	--)
	objList = #()
	for o in selection do (
		append objList o
	)
	clearSelection()
	for obj in objList do (
		select obj
		if obj.modifiers[1] != undefined do (
			if classOf obj.modifiers[1] == Skin do (
				--check if has minus scale
				minusScale = false
				if obj.scale.x<0 do (
					minusScale = true
				)
				if obj.scale.y<0 do (
					minusScale = true
				)
				if obj.scale.z<0 do (
					minusScale = true
				)
				--get the bone list
				boneList = #()
				boneCount = skinOps.getNumberBones obj.modifiers[1]
				for i = 1 to boneCount do (
					append boneList (skinOps.getBoneName obj.modifiers[1] i 0)
				)
				skinOps.saveEnvelope obj.modifiers[1] (maxFilePath + "temp.env")
				deleteModifier obj 1
				ResetXForm obj
				collapseStack obj
				addModifier obj (Skin())
				for j in boneList do (
					skinOps.addBone obj.modifiers[1] (getNodeByName(j)) 0
				)
				skinOps.loadEnvelope obj.modifiers[1] (maxFilePath + "temp.env")
				if minusScale == true do (
					addModifier obj (normalModifier()) before:1
				)
			)
		)
	)

)

function BuildResDirList searchRoot:"Z:\\" = (
	--build directory list
	dirList = #()
	dirBuffer = #()
	subDirList = #()
	append dirList searchRoot
	append dirBuffer searchRoot
	
	while dirBuffer.count>0 do (
		for i in dirBuffer do (
			iSub = getDirectories (i+"*")
			if iSub.count>0 do (
				for j in iSub do (
					append subDirList j
					append dirList j
				)
			)
		)
		
		dirBuffer = #()
		dirBuffer = subDirList
		subDirList = #()
	)
	return dirList
)

function FixDiffuseMapPath = (
	for obj in selection do (
		if obj.material != undefined then (
			fname = undefined
			mType = 0
			if hasProperty obj.material "diffuseMap" then (
				fname = obj.material.diffuseMap.filename
				mType = 1
			)
			if hasProperty obj.material "materialList" then (
				fname = obj.material.materialList[1].diffuseMap.filename
				mType = 2
			)
			
			if fname != undefined then (
				sfn = filenameFromPath fname
				sfp = getFilenamePath fname
				for pn in resourceDirList do (
					if doesFileExist (pn + sfn) do (
						if mType == 1 do (
							obj.material.diffuseMap.fileName = pn + sfn
							print (pn+sfn)
						)
						if mType == 2 do (
							obj.material.diffuseMap.fileName = pn + sfn
							print (pn+sfn)
						)
					)
				)
			)
		)
	)
)

function BatchAnimExport skelFile:undefined expPath:undefined fileList:undefined = (
	if (doesFileExist skelFile == false) do (
		print "骨骼文件名错误"
		return false
	)
	if (doesFileExist expPath == false) do (
		print "导出路径名错误"
		return false
	)
	if (fileList != undefined) do (
		for f in fileList do (
			ff = filterString f "|"
			if (loadMaxFile ff[2] useFileUnits:true quiet:true) do (
				sl = ImportSkelSet fName:skelFile
				ao = animExpOptions true sl animationRange.start animationRange.end
				mo = meshExpOptions #() false "" "" ""
				ExportFBXFile outPath:expPath outFileName:ff[1] animOptions:ao meshOptions:mo
			)
		)
	)
	return true
)

function SetColorByName objName:undefined objColor:undefined = (
	o = getNodeByName(objName)
	if o != undefined do (
		o.wireColor = objColor;
	)
)

function ColorizeBonePairs activeIndex:-1 inputList:undefined = (
	for bp in inputList do (
		nn = filterString bp ">"
		SetColorByName objName:nn[2] objColor:(color 208 226 7)
		SetColorByName objName:nn[1] objColor:(color 48 24 24)
	)
	
	if activeIndex != -1 do (
		nn = filterString inputList[activeIndex] ">"
		SetColorByName objName:nn[2] objColor:(color 7 255 205)
		SetColorByName objName:nn[1] objColor:(color 209 7 7)
	)
)

rollout charDisplayRollout "主角显示控制工具" (
	dropDownList hairDList "头发(Hair):" pos:[8,40] width:264 height:41
	dropDownList faceDList "脸(Face):" pos:[8,96] width:264 height:41
	dropDownList headDList "头(Head):" pos:[8,152] width:264 height:41
	dropDownList bodyDList "身体(Body):" pos:[8,208] width:264 height:41
	dropDownList shoeDList "鞋(Shoe):" pos:[8,320] width:264 height:41
	dropDownList body2DList "身体2(Body):" pos:[8,264] width:264 height:41
	button loadBtn "载入场景物体" pos:[144,8] width:132 height:24
	button renamebtn "按贴图名重命名" pos:[8,8] width:132 height:24
	dropDownList otherDlist "其它(Node):" pos:[8,376] width:264 height:41

	on loadBtn pressed do (
		hairDList.items = GetObjectListByKeyword keyword:"Hair"
		faceDList.items = GetObjectListByKeyword keyword:"Face"
		headDList.items = GetObjectListByKeyword keyword:"Head"
		bodyDList.items = GetObjectListByKeyword keyword:"Body"
		body2DList.items = GetObjectListByKeyword keyword:"Body"
		shoeDList.items = GetObjectListByKeyword keyword:"Shoe"
		otherDList.items = GetObjectListByKeyword keyword:"Node"
	)
	
	on hairDList selected itm do (
		SoloObjectDisplay list:hairDList.items selected:hairDList.selected except:"None"
	)
	on faceDList selected itm do (
		SoloObjectDisplay list:faceDList.items selected:faceDList.selected except:"None"
	)
	on headDList selected itm do (
		SoloObjectDisplay list:headDList.items selected:headDList.selected except:"None"
	)
	on bodyDList selected itm do (
		SoloObjectDisplay list:bodyDList.items selected:bodyDList.selected except:body2DList.selected
	)
	on body2DList selected itm do (
		SoloObjectDisplay list:body2DList.items selected:body2DList.selected except:bodyDList.selected
	)
	on shoeDList selected itm do (
		SoloObjectDisplay list:shoeDList.items selected:shoeDList.selected except:"None"
	)
	on otherDList selected itm do (
		SoloObjectDisplay list:otherDList.items selected:otherDList.selected except:"None"
	)
	on renameBtn pressed do (
		RenameByDiffuseMap()
	)
)

rollout exportRollout "素材输出到FBX工具" width:328 height:632
(
	editText expPathTxt "" text:"E:\Projects\RenderTest\Assets\倩女幽魂美术资源" pos:[8,64] width:216 height:18
	button browseBtn "浏览" pos:[232,56] width:88 height:24
	label exportPathLabel "输出路径:" pos:[16,40] width:200 height:20
	editText fileNameTxt "文件名称" pos:[8,8] width:312 height:16
	dropDownList skelDList "骨骼选择集:" pos:[16,128] width:200 height:41
	button impSkelSetBtn "从文件导入" pos:[224,144] width:88 height:24
	button expSkelBtn "导出当前选择" pos:[224,112] width:88 height:24
	spinner animStartSpn "动画起始：" pos:[44,184] width:124 height:16 range:[-9999,9999,0] type:#integer
	spinner animEndSpn "动画结束:" pos:[196,184] width:116 height:16 range:[-9999,9999,0] type:#integer
	button makeUniqueBtn "Make Unique(Mult)" pos:[184,208] width:128 height:18
	button resetXFormBtn "重设比例和旋转" pos:[184,230] width:128 height:18
	button resetSkinXFormBtn "重设蒙皮模型(Mult)" pos:[36,232] width:140 height:16
	--spinner rootHSpn "?????" pos:[36,232] width:140 height:16 range:[-9999,9999,0]
	button expBtn "输出文件" pos:[16,600] width:296 height:24
	groupBox skelGrp "骨骼和动画" pos:[8,88] width:312 height:168
	editText rootNameTxt "根节点名称" pos:[16,208] width:160 height:16
	groupBox meshGrp "模型" pos:[8,264] width:312 height:328
	listBox meshExpLB "待导出模型列表：" pos:[16,280] width:296 height:9
	button addMeshBtn "添加当前选择物体" pos:[16,424] width:136 height:16
	button removeMeshBtn "从列表中移除" pos:[168,424] width:144 height:16
	checkbox copyTexChk "复制贴图" pos:[16,448] width:3112 height:16
	radioButtons texOptionRB "贴图路径" pos:[16,472] width:261 height:46 labels:#("自动建立目录（导出目录/Texture）", "手动指定目录") columns:1
	editText texPathTxt "" pos:[16,528] width:216 height:16
	button browseTexPathBtn "浏览" pos:[240,528] width:72 height:16
	checkbox animExpChk "输出动画" pos:[16,104] width:200 height:16
	label texSourceLabel "贴图来源路径修复" pos:[16, 548] width:216 height:16
	editText texSourceTxt "资源根目录:" text:"Z:\\" pos:[16, 568] width:144 height:16
	--editText texReplaceTxt "替换为:" text:"Z:\\Alien" pos:[168, 568] width:144 height:16
	button texSrcBtn "浏览" pos:[168, 568] width:64 height:16
	button texFixBtn "修复" pos:[168+72, 568] width:64 height:16
	
	on exportRollout open do (
		skelDList.items = UpdateSetDList()
		--rootHSpn.enabled = False
		rootNameTxt.enabled = False
	)
	
	on browseBtn pressed do (
		p = getSavePath caption:"指定输出路径" initialDir:expPathTxt.text
		if p != undefined do (
			expPathTxt.text = p
		)
	)
	
	on browseTexPathBtn pressed do (
		p = getSavePath caption:"指定贴图输出路径" initialDir:texPathTxt.text
		if p != undefined do (
			texPathTxt.text = p
		)
	)
	
	on skelDList selected arg do (
		skelDList.items = UpdateSetDList()
	)
	
	on expSkelBtn pressed do (
		ExportSkelSet setName:skelDList.selected
	)
	
	on impSkelSetBtn pressed do (
		local sn = ImportSkelSet fName:undefined
		skelDList.items = UpdateSetDList()
		skelDList.selected = sn
	)
	
	on makeUniqueBtn pressed do (
		MakeTopModUnique()
	)
	
	on addMeshBtn pressed do (
		meshExpLB.items = AddNameToArray source:meshExpLB.items
	)
	
	on removeMeshBtn pressed do (
		meshExpLB.items = RemoveNameFromArray source:meshExpLB.items item:meshExpLB.selected
	)
	
	--struct animExpOptions(isExport = True, skelSet = "", animStart = 0, animEnd = 30)
	--struct meshExpOptions(objList = #(), texExport = True, texPath = "", texSource = "", texReplace = "")
	on expBtn pressed do (
		ao = animExpOptions animExpChk.checked  skelDList.selected animStartSpn.value animEndSpn.value
		if texOptionRB.state == 2 then (
			tp = texPathTxt.text
		)
		else (
			tp = undefined
		)
		print (texOptionRB.state)
		mo = meshExpOptions meshExpLB.items copyTexChk.checked tp "" ""
		ExportFBXFile outPath:expPathTxt.text outFileName:fileNameTxt.text animOptions:ao meshOptions:mo
	)
	on resetXFormBtn pressed do (
		ResetAndFlipNormal()
	)
	on resetSkinXFormBtn pressed do (
		ResetSkinXForm()
	)
	on texSrcBtn pressed do (
		p = getSavePath caption:"指定资源根目录" initialDir:texSourceTxt.text
		if p != undefined do (
			texSourceTxt.text = p
			resourceDirList = BuildResDirList searchRoot:texSourceTxt.text
		)
	)
	on texFixBtn pressed do (
		if resourceDirList.count > 0 do (
			FixDiffuseMapPath()
		)
	)
)

rollout optimizeRollout "骨骼优化工具" width:376 height:592
(
	listBox bonePairList "骨骼替换关系列表" pos:[8,128] width:360 height:27
	label helpLabel "先选择被替换的骨骼，后选择目标骨骼，然后按添加，即可把对应关系添加到列表中，max必须处于修改器面板" pos:[8,8] width:360 height:48
	button addPairBtn "添加替换关系" pos:[8,64] width:176 height:24
	button removePairbtn "移除所选替换关系" pos:[192,64] width:176 height:24
	button editSkinBtn "替换当前选择物体骨骼权重" pos:[8,512] width:360 height:32
	button removeBtn "去除没有影响的骨骼" pos:[8,548] width:360 height:32
	button saveDefBtn "保存为文件" pos:[8,96] width:176 height:24
	button loadDefbtn "从文件中读取" pos:[192,96] width:176 height:24
	
	on bonePairList selected arg do (
		ColorizeBonePairs activeIndex:arg inputList:bonePairList.items
	)
	
	on addPairBtn pressed do (
		bonePairList.items = AddBonePair inputList:bonePairList.items
		ColorizeBonePairs activeIndex:-1 inputList:bonePairList.items
	)
	on removePairBtn pressed do (
		bonePairList.items = RemoveBonePair input:bonePairList.selected inputList:bonePairList.items
		ColorizeBonePairs activeIndex:-1 inputList:bonePairList.items
	)
	on saveDefBtn pressed do (
		ExportBonePairs inputList:bonePairList.items
	)
	on loadDefBtn pressed do (
		bonePairList.items = ImportBonePairs inputList:bonePairList.items
	)
	on editSkinBtn pressed do (
		ReplaceSkinWeights inputList:bonePairList.items
	)
	on removeBtn pressed do (
		RemoveUnusedBones()
	)
)

rollout batchAnimRollout "批量动画导出" width:360 height:560
(
	label skelFileLabel "骨骼文件：" pos:[8, 16] width:348 height:24
	editText skelFileTxt "" pos:[8, 40] width:300 height:24
	button importSkelBtn "选择" pos:[312, 40] width:44 height:24
	button addFileBtn "添加文件" pos:[8, 72] width:80 height:24
	button addDirBtn "添加目录" pos:[96, 72] width:80 height:24
	button removeFileBtn "移除当前选择" pos:[184, 72] width:80 height:24
	button removeAllBtn "移除所有" pos:[272, 72] width:80 height:24
	listBox animFileList "动画文件列表" pos:[8, 100] width:348 height:24
	editText exportPathTxt "" pos:[8, 440] width:270 height:24
	button exportPathBtn "选择目录" pos:[286, 440] width:68 height:24
	button exportBtn "导出动画文件" pos:[8, 472] width:348 height:24
	
	on addFileBtn pressed do (
		fname = getOpenFileName caption:"选择动画文件" types:"3ds max files(*.max)|*.max"
		if (fname != undefined) do (
			flist = animFileList.items
			append flist ((getFilenameFile fname) + "|" + fname)
			animFileList.items = flist
		)
	)
	
	on addDirBtn pressed do (
		dname = getSavePath caption:"选择动画文件目录"
		if (dname != undefined) do (
			flist = animFileList.items
			files = getFiles (dname + "\\*.max")
			if (files.count>0) do (
				for f in files do (
					append flist ((getFilenameFile f) + "|" + f)
				)
				animFileList.items = flist
			)
		)
	)
	
	on removeFileBtn pressed do (
		flist = animFileList.items
		if (animFileList.selection>0) do (
			deleteItem flist animFileList.selection
			animFileList.items = flist
		)
	)
	
	on removeAllBtn pressed do (
		animFileList.items = #()
	)
	
	on importSkelBtn pressed do (
		fname = getOpenFileName caption:"选择骨骼文件" types:"Text files (*.txt)|*.txt"
		if (fname != undefined) do (
			skelFileTxt.text = fname
		)
	)
	
	on exportPathBtn pressed do (
		dname = getSavePath caption:"选择导出目录"
		if (dname != undefined) do (
			exportPathTxt.text = dname
		)
	)
	
	on exportBtn pressed do (
		BatchAnimExport skelFile:skelFileTxt.text expPath:exportPathTxt.text fileList:animFileList.items
	)
)

utility QN_Asset_Management "倩女幽魂美术素材管理"
(
	local charFloater;
	local expFloater;
	local optFloater;
	local batchAnimFloater;
	
	button charBtn "主角显示控制" width:120;
	button expBtn "FBX输出工具" width:120;
	button optBtn "骨骼优化工具" width:120;
	button batchAnimBtn "批量动画导出" width:120;
	on charBtn pressed do (
		charFloater = newRolloutFloater "主角" 300 460;
		addRollout charDisplayRollout charFloater;		
	)
	
	on expBtn pressed do (
		expFloater = newRolloutFloater "输出" 336 656;
		addRollout exportRollout expFloater;		
	)
	
	on optBtn pressed do (
		optFloater = newRolloutFloater "优化骨骼" 388 620;
		addRollout optimizeRollout optFloater;		
	)
	
	on batchAnimBtn pressed do (
		batchAnimFloater = newRolloutFloater "动画批量导出" 372 572;
		addRollout batchAnimRollout batchAnimFloater;
	)
)