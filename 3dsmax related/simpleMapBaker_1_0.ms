macroScript simpleMapBaker
	category:"csTools"
	toolTip:"simpleMapBaker"
(
	global simpleMapBaker	
	try(destroyDialog simpleMapBaker)catch()
	global csBTT
	struct csBTT (
		public BTTelemIDdict,
		public makeNormalizeBBOSL,
		public BTT = BakeToTexture,
		public bakeElemIDDic = (this.getBakeElemIDDict()),
		public idcolors = #(),
		public bakeResult = #(),
		fn getBakeElemIDDict = (
			local result = dictionary()
			for bkElelm in BakeElement.classes do (
				if bkElelm.creatable then (
					tmpElem = bkElelm()
					result[(tmpElem.elementName as name)] = (tmpElem.classid)
				)
			)
			result
		),
		fn getBakeMapOptionIDDict bakemap = (
			local result = Dictionary #name
			local bakemapOptionCount = (bakemap.getOptionsCount())
			if bakemapOptionCount > 0 then (
				for i = 1 to bakemapOptionCount do (
					result[(bakemap.getOptionName i) as name] = i
				)
			)
			result
		),
		
		fn addBakeMap argObj maptype mapname:undefined ext:"tga" uv:1 imgsize:2048 padding:2 bgcolor:(color 0 0 0) hiresGeo:undefined prjmth:1 pushamt:0.0 pushper:0.0 = (
-- 			format "bgcolor %\n" bgcolor
			local bkMap
			local bakeElemID = this.bakeElemIDDic[maptype] 
			if bakeElemID != undefined then (
				bkMap = this.BTT.addMapByClassID argObj bakeElemID
				if mapname == undefined then (mapname = (maptype as string))
				bkMap.filename = (argObj.name + "_" + mapname)
				bkMap.fileType = ext
				bkMap.uvChannel = uv
				bkMap.imageWidth = imgsize
				bkMap.imageHeight = imgsize	
				bkMap.edgePadding = padding			
				bkMap.backgroundColor = bgcolor
-- 				format "bkMap.backgroundColor  %\n" bkMap.backgroundColor 
				if hiresGeo != undefined then (
					format "Adding hires geo\n"
					for o in hiresGeo do (format "%\n" o.name)
					addPModObjects argObj (argObj.modifiers[Projection] == undefined) true objList:hiresGeo
					bkMap.projectionModifierIndex = (modPanel.getModifierIndex argObj argObj.modifiers[Projection] )
					bkMap.projectionMethod = (prjmth - 1)
					argObj.modifiers[bkMap.projectionModifierIndex].pushCage pushamt
					argObj.modifiers[bkMap.projectionModifierIndex].pushPercent = pushper
					format "bkMap.projectionMethod %\n" bkMap.projectionMethod
				)
				else (
					bkMap.projectionModifierIndex = 0
				)
			)
			else(
				format "> % is not an available type.\n" maptype
			)
			bkMap
		),
		fn setBakeElemOption bakemap optionname optionVal = (
			local optionIDDic = (this.getBakeMapOptionIDDict bakemap)
			local optionID = optionIDDic[(optionname as name)]
			if optionID != undefined then (
				bakemap.setOptionValue optionID optionVal
			)
			else(
				format "> % is not an available option name.\n" maptype
			)
		),		
			
-- 		fn onMapBaked successfulBake render_result = (           
-- 			if successfulBake then (
-- 				append this.bakeResult render_result
-- 			)
-- 			true
-- 		),	
		fn getObjCenterLocalPos obj = (
			obj.center*(inverse obj.transform)
		),
		fn getBoundingSphere obj = (
			local allVerts = for i in 1 to obj.mesh.numVerts collect (GetVert (obj.mesh) i)
			local objCenterPos = (getObjCenterLocalPos obj)
			local vDist = for i in allVerts collect (distance i objCenterPos)
			sort vDist
			bs_Radius = vDist[vDist.count] -- BSphere Radius
			bs_Radius
		),	
		fn getLocalBoundingBox obj = (
			local bb = (in coordsys local nodeLocalBoundingBox obj)
			[(abs(bb[1].x) + abs(bb[2].x)), (abs(bb[1].y) + abs(bb[2].y)), (abs(bb[1].z) + abs(bb[2].z))]
		),
		fn makeNormalizeBBOSLmap = (
			local normalizedVectorByBBCode = @"shader normalizedVectorByBB
			(
				vector In = 0.0,
				vector bbbox  = 1.0, 
				vector offset = 0.0,
				output color Out = 0.0
			)
			{
				Out = (In - offset + bbbox)/(bbbox*2.0); 
			}"
			local normalizedVectorByBBOSL = (OSLMap())
			normalizedVectorByBBOSL.OSLCode = normalizedVectorByBBCode
			this.makeNormalizeBBOSL = normalizedVectorByBBOSL
		),
		fn makeObjPosOSL obj multiply:1.0 = (
-- 			local st = timestamp()
-- 			format "-- %s\n" (((timestamp()) - st)/1000.0)
			local objP = (osl_GetCoordSpace Coordspace:"object")
			local normbyBB =  (copy this.makeNormalizeBBOSL)	
-- 			format "-- %s\n" (((timestamp()) - st)/1000.0)			
			normbyBB.In_map = objP
			normbyBB.offset = (this.getObjCenterLocalPos obj)
			normbyBB.bbbox = (this.getLocalBoundingBox obj)*0.5*multiply
-- 			format "-- %s\n" (((timestamp()) - st)/1000.0)			
			normbyBB
		),				
		fn makeWorldNormalOSL = (
			local worldN = (osl_Normal Coordspace:"world")
			local normbyBB = (copy this.makeNormalizeBBOSL)
			normbyBB.In_map = worldN
			normbyBB
		),		
		fn makeArnoldCurvatureMap samples:3 radius:0.1 spread:1.0 threshold:0.0 bias:0.5 multiply:1.0 = (
			(ai_curvature output:2 samples:samples radius:radius spread:spread threshold:threshold bias:bias multiply:multiply)
		),
		fn makeArnoldAOMap samples:3 spread:1.0 falloff:0.0 near:0.0 far:0.5 white:(color 255 255 255) black:(color 0 0 0) = (
			result = (ai_ambient_occlusion samples:samples spread:spread falloff:falloff near_clip:near far_clip:far white:white black:black)
		),	
		fn makeVertexColorMap = (
			(osl_GetUVW UVSet:0)
		),		
		fn getelements obj= (
			local f = obj.numfaces
			local eles=#()
			local done=#()
			for i = 1 to f do (
				if (finditem done i) == 0 then (
					local faces=((meshop.getElementsUsingFace obj #(i)) as array)
					format "% %\n" i faces
					append eles faces
					join done faces
				)
			)
			return eles
		),		
		fn makeMatIDMap = (
			(osl_GetMtlID())
		),
		on create do (
			BTTelemIDdict = (this.getBakeElemIDDict())
			this.makeNormalizeBBOSLmap()		
-- 			this.genreateIDcolors()
		)
	)
	local bakem = csBTT()
	
	local buttonCount = 7
	local bakeBtnHeight = 48
	local rolWidth = (bakeBtnHeight*buttonCount + 16)
	local bakeFormats = #("TGA", "PNG", "JPG", "EXR", "BMP", "TIF")	
	rollout simpleMapBaker "simpleMapBaker 1.0" (
		checkbutton curvChkbtn "Curva ture" height:bakeBtnHeight width:bakeBtnHeight align:#center across:buttonCount
		checkbutton aoChkbtn "AO" height:bakeBtnHeight width:bakeBtnHeight align:#center 	
		checkbutton PosChkbtn "Position" height:bakeBtnHeight width:bakeBtnHeight align:#center 
		checkbutton worldNChkbtn "World Normal" height:bakeBtnHeight width:bakeBtnHeight align:#center 
		checkbutton vertexcolorChkbtn "Vertex Color" height:bakeBtnHeight width:bakeBtnHeight align:#center
		checkbutton mtlIDChkbtn "Material IDs" height:bakeBtnHeight width:bakeBtnHeight align:#center
		checkbutton normalChkbtn "Normal" height:bakeBtnHeight width:bakeBtnHeight align:#center

		group "Curvature" (
			spinner curvSamplesSpnr "Samples" fieldwidth:32 range:[0, 9999, 3] type:#integer across:3 align:#right
			spinner curvRadiusSpnr "Radius" fieldwidth:32 range:[0, 9999, 10.0] align:#right
			spinner curvSpreadSpnr "Spread" fieldwidth:32 range:[0, 1.0, 1.0] align:#right
			spinner curvThresholdSpnr "Threshold" fieldwidth:32 range:[0, 1.0, 0.0] align:#right across:3
			spinner curvBiasSpnr "Bias" fieldwidth:32 range:[0, 1.0, 0.5] align:#right	
			spinner curvMultiplySpnr "Multiply" fieldwidth:32 range:[-99999, 99999, 1.0] align:#right				
		)		
		group "AO" (
			spinner aoSamplesSpnr "Samples" fieldwidth:32 range:[0, 9999, 3] type:#integer across:3 align:#right
			spinner aoSpreadSpnr "Spread" fieldwidth:32 range:[0, 1.0, 1.0] align:#right
			spinner aoFalloffSpnr "Falloff" fieldwidth:32 range:[-99999, 99999, 0.0] align:#right			
			colorpicker aoWClrpkr "White:" color:[255,255,255] modal:false across:4 align:#right
			colorpicker aoBClrpkr "Black:" color:[0,0,0] modal:false align:#right
			spinner aoNearClipSprn "Near" fieldwidth:36 range:[0, 99999.0, 10.0] align:#right 
			spinner aoFarClipSprn "Far" fieldwidth:36 range:[0, 99999.0, 100.0] align:#right	
-- 			spinner curvMultiplySpnr "Multiply" fieldwidth:32 range:[-99999, 99999, 1.0] align:#right	
		)			
		group "Position" (
-- 			checkbox byBBChkbx "Use BoundingBox" across:2
			spinner bbMulSpnr "Multiplier" align:#right  fieldwidth:28 range:[0.001, 9999.0, 1.0]
-- 			spinner customBBSpnr "Custom BB Size" align:#right fieldwidth:28 range:[0.001, 9999.0, 10.0]
		)
		group "Normal" (
			radiobuttons prjMethodRbtn "Projection Method" labels:#("Cage", "Raytrace", "UV Match") columns:3 offsets:#([102, -16],[22,-16],[-40, -16]) align:#left
			spinner cagePushAmtSpnr "Cage               Push.Amount" align:#left fieldwidth:40 across:2
			spinner cagePushPercentSpnr "Push.Percent" align:#right fieldwidth:40
			edittext normalSuffixEtxt "Hires Geo Suffix" text:"high" width:(simpleMapBaker.width/2) align:#left across:2
			checkbox multiHires "Multiple Hires Geo" align:#right offset:[8, 1]
		) 
		group "Map options | Bake" (
			button outputPathBtn "Select output path" width:(rolWidth - 16) border:false align:#left 
			button bakeBtn "Bake" width:(rolWidth/3*2 - 32) height:90 align:#left 
			dropdownlist extDrpdnlst "" items:bakeFormats width:(rolWidth/6) align:#right across:2 pos:(bakeBtn.pos + [(bakeBtn.width + 4), 0])
			dropdownlist sizeDrpdnlst "" items:#("256", "512", "1024", "2048", "4096") selection:4 width:(rolWidth/6) align:#right pos:(extDrpdnlst.pos + [(extDrpdnlst.width + 4), 0])
			spinner uvSpnr "UV" fieldwidth:20 range:[0, 99, 1] type:#integer width:(rolWidth/6) align:#right 
			spinner paddingSpnr "Padding" fieldwidth:20 range:[0, 99, 2] type:#integer width:(rolWidth/6) align:#right 		
			colorpicker bgcolorPckr "BackgroundColor" align:#right color:black offset:[0, 0] fieldwidth:30

		)
		group "Result Preview" (
			dropdownlist prvDrpdnLst "" width:(rolWidth - 24 - 60) align:#left across:2
			button reloadBtn "Reload" width:60 align:#right
		)

		on simpleMapBaker open do (
			escapeEnable = true
			outputPathBtn.text = outputPathBtn.tooltip = (getdir #image)
		)
		on outputPathBtn pressed do (
			local outputPath = getSavePath()
			if outputPath != undefined then (
				outputPathBtn.text = outputPathBtn.tooltip = outputPath
			)
		)
		on outputPathBtn rightclick do (
			if (doesFIleExist outputPathBtn.tooltip) then (			
				shellLaunch outputPathBtn.tooltip ""
			)
		)		

		fn addBakeMaps o = (	
			format "Generating bake maps : %\n" o.name
			local bakedata = #()
			if curvChkbtn.checked then ( 
				local map2use = (bakem.makeArnoldCurvatureMap samples:curvSamplesSpnr.value radius:curvRadiusSpnr.value spread:curvSpreadSpnr.value threshold:curvThresholdSpnr.value bias:curvBiasSpnr.value multiply:curvMultiplySpnr.value)						
				append bakedata #(#Arnold_map_override, "Curvature", map2use)
			)
			if aoChkbtn.checked then ( 
				local map2use = (bakem.makeArnoldAOMap samples:aoSamplesSpnr.value spread:aoSpreadSpnr.value falloff:aoFalloffSpnr.value near:aoNearClipSprn.value far:aoFarClipSprn.value white:aoWClrpkr.color black:aoBClrpkr.color)		
				append bakedata #(#Arnold_map_override, "AO", map2use)						
			)		
			if PosChkbtn.checked then ( 
				local map2use = (bakem.makeObjPosOSL o multiply:bbMulSpnr.value)	
				append bakedata #(#Arnold_map_override, "Position", map2use)								
			)	
			if worldNChkbtn.checked then ( 
				local map2use =  (bakem.makeWorldNormalOSL()) 			
				append bakedata #(#Arnold_map_override, "WorldNormal", map2use)								
			)	
			if vertexcolorChkbtn.checked then ( 
				local map2use = (bakem.makeVertexColorMap())						
				append bakedata #(#Arnold_map_override, "VertexColor", map2use)								
			)					
			if mtlIDChkbtn.checked then ( 
				local map2use = (bakem.makeMatIDMap())						
				append bakedata #(#Arnold_map_override, "MaterialID", map2use)								
			)					
-- 			format "bgcolorPckr.color %\n" bgcolorPckr.color
			for bd in bakedata do (
				local addedBkmap = bakem.addBakeMap o bd[1] mapname:bd[2] ext:extDrpdnlst.selected uv:uvSpnr.value imgsize:(sizeDrpdnlst.selected as integer) padding:paddingSpnr.value bgcolor:bgcolorPckr.color
				if  bd[3] != undefined then (
					bakem.setBakeElemOption addedBkmap #map bd[3] 
				)
			)		
		)
		fn addNormalBakeMaps lowobj = (	
			local hiresGeoName =  lowobj.name + "_" + normalSuffixEtxt.text 
			local hiresGeo = #()
			local singleHiresGeo = (getNodeByName hiresGeoName)
			if singleHiresGeo != undefined then (append hiresGeo singleHiresGeo)
			if multiHires.checked then (
				hiresGeo = ((execute ("$'" + hiresGeoName + "???'")) as array)
			)
			local hidedata = #()			
			if hiresGeo != undefined and hiresGeo.count > 0 then (		
				for o in hiresGeo do (
					append hidedata #(o, o.isHidden, o.layer)
					lowobj.layer.addnode o
				)
				unhide hiresGeo
				local addedBkmap = bakem.addBakeMap lowobj #NormalsMap mapname:"Normal" ext:extDrpdnlst.selected uv:uvSpnr.value imgsize:(sizeDrpdnlst.selected as integer) padding:paddingSpnr.value bgcolor:(color 128 128 255) hiresgeo:hiresGeo prjmth:prjMethodRbtn.state pushamt:cagePushAmtSpnr.value pushper:cagePushPercentSpnr.value  

				showInterface addedBkmap
			)
			else(
				messagebox "Faile to find hires geo"
			)	
			hidedata
		)			
		on bakeBtn pressed do (
			if selection.count > 0 then (
				local sel = (selection as array)
				prvDrpdnLst.items = bakem.bakeResult = #()				
				local rps2restoreFullpath = ((getdir #renderassets) + "\\simpleMapBaker.rps")
				renderpresets.Save 0 rps2restoreFullpath (renderpresets.SaveCategories 0)	 					
				makedir outputPathBtn.text all:true
				for o in sel do (
					if curvChkbtn.checked or aoChkbtn.checked or PosChkbtn.checked or worldNChkbtn.checked or vertexcolorChkbtn.checked or mtlIDChkbtn.checked then (
						bakem.BTT.deleteAllMaps()		
						renderers.current = (Arnold())
						addBakeMaps o
						BakeToTexture.bake()
					)
					if normalChkbtn.checked then (
						bakem.BTT.deleteAllMaps()		
						renderers.current = (DefaultScanlineRenderer())
						local hidedata = (addNormalBakeMaps o)
						BakeToTexture.bake()	
						for hd in hidedata do (
							hd[1].isHidden = hd[2]
							 hd[3].addnode hd[1]
						)
					)
				)
				renderpresets.LoadAll  0 rps2restoreFullpath 
				prvDrpdnLst.items = (for bm in bakem.bakeResult collect (filenameFromPath bm))
				reloadBtn.pressed()
			)
			else(
				messagebox "Select object(6s)"
			)
		)
		on prvDrpdnLst selected arg do (
			local selectedResult = (outputPathBtn.text + "\\" +  prvDrpdnLst.selected)
			local tmpVptMtl = (Standard selfIllumAmount:100.0)
			local tmpbitmap = (bitmaptexture filename:selectedResult)
			tmpbitmap.coords.mapChannel = uvSpnr.value
			tmpVptMtl.diffuseMap = tmpbitmap
			nitrousgraphicsmanager.OverrideRenderSettingMtl = tmpVptMtl
			meditMaterials[1] = tmpVptMtl
			local viewsetting = nitrousgraphicsmanager.getactiveviewportsetting()
			viewsetting.overridematerialoption = #renderingsetting
		)
		on reloadBtn pressed do (
			local allMaps = #()
			for o in selection do (
				join allMaps (for f in (getFIles (outputPathBtn.text + "\\" + o.name + "*." +extDrpdnlst.selected)) collect (filenameFromPath f))
			)
			prvDrpdnLst.items = allMaps
		)
	)		
	createDialog simpleMapBaker width:rolWidth
)
