component output="false" hint="Main filebrowser module handler"{
	
	// DI
	property name="antiSamy"		inject="coldbox:plugin:AntiSamy";
	property name="fileUtils"		inject="coldbox:plugin:FileUtils";
	
	function preHandler(event,currentAction){
		var prc = event.getCollection(private=true);
		// place root in prc and also module settings
		prc.modRoot	 = event.getModuleRoot();
		prc.settings = getModuleSettings("filebrowser").settings;
	}
	
	function index(event,rc,prc){
		// params
		event.paramValue("path","");
		event.paramValue("callback","");
		event.paramValue("cancelCallback","");
		
		// exit handlers
		prc.xehBrowser 		= "filebrowser/";
		prc.xehNewFolder 	= "filebrowser/createfolder";
		prc.xehRemove 		= "filebrowser/remove";
		prc.xehDownload		= "filebrowser/download";
		
		// Load CSS and JS only if not in Ajax Mode
		if( NOT event.isAjax() ){
			addAsset("#prc.modRoot#/includes/css/style.css");
			if( prc.settings.loadJquery ){
				addAsset("#prc.modRoot#/includes/javascript/jquery-1.4.4.min.js");
			}
			addAsset("#prc.modRoot#/includes/javascript/jquery.uidivfilter.js");
		}
		
		// Inflate flash params
		inflateFlashParams(event,rc,prc);
		
		// clean incoming path
		rc.path = URLDecode( trim( antiSamy.clean( rc.path ) ) );
		// Store directory root
		prc.dirRoot 	= prc.settings.directoryRoot;
		// Get the current Root
		if( !len(rc.path) ){
			prc.currentRoot = prc.settings.directoryRoot;
		}
		else{
			prc.currentRoot = rc.path;
		}
		prc.currentRoot = REReplace(prc.currentRoot,"(/|\\){1,}$","","all");
		prc.currentRoot = REReplace(prc.currentRoot,"\\","/","all");
		
		// Do a safe current root
		prc.safeCurrentRoot = URLEncodedFormat( prc.currentRoot );
		
		// traversal test
		if( prc.settings.traversalSecurity AND NOT findNoCase(prc.settings.directoryRoot, prc.currentRoot) ){
			getPlugin("MessageBox").warn("Traversal security exception");
			setNextEvent(prc.xehBrowser);
		}
		
		// get directory listing.
		prc.qListing = directoryList( prc.currentRoot, false, "query", prc.settings.extensionFilter, "asc");
		
		// view
		event.setView(view="home/index",noLayout=event.isAjax());
	}
	
	/**
	* Creates folders asynchrounsly return json information: 
	*/
	function createfolder(event,rc,prc){
		var data = {
			errors = false,
			messages = ""
		};
		// param value
		event.paramValue("path","");
		event.paramValue("dName","");
		
		// Verify credentials else return invalid
		if( !prc.settings.createFolders ){
			data.errors = true;
			data.messages = "CreateFolders permission is disabled.";
			event.renderData(data=data,type="json");
			return;
		}
		
		// clean incoming path and names
		rc.path = URLDecode( trim( antiSamy.clean( rc.path ) ) );
		rc.dName = URLDecode( trim( antiSamy.clean( rc.dName ) ) );
		if( !len(rc.path) OR !len(rc.dName) ){
			data.errors = true;
			data.messages = "The path and name sent are invalid!";
			event.renderData(data=data,type="json");
			return;
		}
		
		// creation
		try{
			fileUtils.directoryCreate( rc.path & "/" & rc.dName );
			data.errors = false;
			data.messages = "Folder '#rc.path#/#rc.dName#' created successfully!";
		}
		catch(Any e){
			data.errors = true;
			data.messages = "Error creating folder: #e.message# #e.detail#";
			log.error(data.messages, e);
		}
		// render stuff out
		event.renderData(data=data,type="json");
	}
	
	/**
	* Removes folders + files asynchrounsly return json information: 
	*/
	function remove(event,rc,prc){
		var data = {
			errors = false,
			messages = ""
		};
		// param value
		event.paramValue("path","");
		
		// Verify credentials else return invalid
		if( !prc.settings.deleteStuff ){
			data.errors = true;
			data.messages = "Delete Stuff permission is disabled.";
			event.renderData(data=data,type="json");
			return;
		}
		
		// clean incoming path and names
		rc.path = URLDecode( trim( antiSamy.clean( rc.path ) ) );
		if( !len(rc.path) ){
			data.errors = true;
			data.messages = "The path sent is invalid!";
			event.renderData(data=data,type="json");
			return;
		}
		
		// removal
		try{
			if( fileExists( rc.path ) ){
				fileUtils.removeFile( rc.path );
			}
			else if( directoryExists( rc.path ) ){
				fileUtils.directoryRemove(path=rc.path,recurse=true);
			}
			data.errors = false;
			data.messages = "'#rc.path#' removed successfully!";
		}
		catch(Any e){
			data.errors = true;
			data.messages = "Error removing stuff: #e.message# #e.detail#";
			log.error(data.messages, e);
		}
		// render stuff out
		event.renderData(data=data,type="json");
	}
	
	/**
	* download file
	*/
	function download(event,rc,prc){
		var data = {
			errors = false,
			messages = ""
		};
		// param value
		event.paramValue("path","");
		
		// Verify credentials else return invalid
		if( !prc.settings.allowDownload ){
			data.errors = true;
			data.messages = "Download permission is disabled.";
			event.renderData(data=data,type="json");
			return;
		}
		
		// clean incoming path and names
		rc.path = URLDecode( trim( antiSamy.clean( rc.path ) ) );
		if( !len(rc.path) ){
			data.errors = true;
			data.messages = "The path sent is invalid!";
			event.renderData(data=data,type="json");
			return;
		}
		
		// download
		try{
			fileUtils.sendFile(file=rc.path);
			data.errors = false;
			data.messages = "'#rc.path#' sent successfully!";
		}
		catch(Any e){
			data.errors = true;
			data.messages = "Error downloading file: #e.message# #e.detail#";
			log.error(data.messages, e);
		}
		// render stuff out
		event.renderData(data=data,type="json");
	}
	
	/**
	* Inflate flash params if they exist into the appropriate function variables.
	*/
	private function inflateFlashParams(event,rc,prc){
		// Check for incoming callback via flash, else default from incoming rc.
		if( structKeyExists( flash.get( "fileBrowser", {} ), "callback") ){
			rc.callback = flash.get("fileBrowser").callback;
		}
		// clean callback
		rc.callBack = antiSamy.clean( rc.callback );
		// cancel callback
		if( structKeyExists( flash.get( "fileBrowser", {} ), "cancelCallback") ){
			rc.cancelCallback = flash.get("fileBrowser").cancelCallback;
		}
		// clean callback
		rc.cancelCallback = antiSamy.clean( rc.cancelCallback );
		
		// keep flash backs
		flash.keep("filebrowser");
	}
	
}