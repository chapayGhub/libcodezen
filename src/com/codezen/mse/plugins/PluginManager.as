package com.codezen.mse.plugins
{
	import com.codezen.helper.Worker;
	import com.codezen.mse.playr.PlayrTrack;
	import com.codezen.mse.search.ISearchProvider;
	
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.FileListEvent;
	import flash.events.IOErrorEvent;
	import flash.filesystem.File;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.system.ApplicationDomain;
	import flash.system.LoaderContext;
	
	import mx.controls.Alert;
	import mx.utils.ObjectUtil;
	import mx.utils.object_proxy;
	
	public final class PluginManager extends Worker
	{
		// plugins array
		private var _plugins:Array;
		
		// loaders
		private var urlReq:URLRequest;			
		private var urlLoad:URLLoader;
		private var loader:Loader;
		
		// load queue
		private var _loadQueue:Array;
		
		// plugins dir
		private var _dirs:Array;
		// file class
		private var _file:File;
		
		// context
		private var context:LoaderContext;
		
		// counter
		private var dircounter:int;
		private var counter:int;
		// search query
		private var query:String;
		// result url
		private var _results:Vector.<PlayrTrack>;
		
		public function PluginManager(dirs:Array)
		{
			// init results
			_results = new Vector.<PlayrTrack>();
			
			// save dir
			_dirs = dirs.concat();
			
			// init plugins array
			_plugins = [];			
			
			// load plugins
			dircounter = _dirs.length;
			loadPlugins();
		}
		
		// load all plugins from set dir

		public function get results():Vector.<PlayrTrack>
		{
			return _results;
		}

		private function loadPlugins():void{
			dircounter--;
			if(dircounter < 0){
				dispatchEvent(new Event(Event.INIT));
				return;
			}
			_file = new File(_dirs[dircounter]);
			if(!_file.exists){
				loadPlugins();
				return;
			}
			_file.addEventListener(FileListEvent.DIRECTORY_LISTING, onListing);
			//_file.addEventListener(IOErrorEvent.IO_ERROR, onFolderError);
			_file.getDirectoryListingAsync();
		}
		
		// parse listing of files
		private function onListing(e:FileListEvent):void{
			var contents:Array = e.files;
			
			_loadQueue = [];
			
			var cFile:File;
			for (var i:int = 0; i < contents.length; i++) {
				cFile = contents[i] as File;
				_loadQueue.push(cFile.url);
				//loadPluginFromPath(cFile.url);
			}
			
			counter = _loadQueue.length;
			loadPluginsFromPath();
		}
		
		// load plugin from path
		private function loadPluginsFromPath():void{
			var path:String = _loadQueue[ _loadQueue.length - counter ];
			urlReq = new URLRequest(path);			
			urlLoad = new URLLoader();
			urlLoad.dataFormat = URLLoaderDataFormat.BINARY;
			urlLoad.addEventListener(Event.COMPLETE, onPluginData);
			urlLoad.load(urlReq);
		}
		
		private function onPluginData(e:Event):void{
			urlLoad.removeEventListener(Event.COMPLETE, onPluginData);
			
			// create context
			context = new LoaderContext(false, ApplicationDomain.currentDomain );
			context.allowCodeImport = true;
			context.applicationDomain = new ApplicationDomain(ApplicationDomain.currentDomain);
			// create loader
			loader = new Loader();
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onPluginLoaded);
			loader.loadBytes(urlLoad.data, context);
		}
		
		private function onPluginLoaded(e:Event):void{
			loader.contentLoaderInfo.removeEventListener(Event.COMPLETE, onPluginLoaded);
			
			var className:Class = loader.contentLoaderInfo.applicationDomain.getDefinition("Searcher") as Class;
			var classInstance:ISearchProvider = new className();
			_plugins.push(classInstance);
			
			checkInit();
		}
		
		private function checkInit():void{
			counter--;
			if(counter <= 0){
				if(dircounter <= 0){
					trace( 'done: '+ObjectUtil.toString(_plugins) );
				
					dispatchEvent(new Event(Event.INIT));
				}else{
					loadPlugins();
				}
			}else{
				loadPluginsFromPath();
			}
		}
		
		/*private function onFolderError(e:Event):void{
			if(dircounter <= 0){
				trace( 'done: '+ObjectUtil.toString(_plugins) );
				
				dispatchEvent(new Event(Event.INIT));
			}else{
				loadPlugins();
			}
		}*/
		
		// -------------------------------------------
		public function findURLs(query:String, durMs:int):void{
			trace('starting search for: '+query);
			counter = 0;
			this.query = query;
			_results = new Vector.<PlayrTrack>();
			var searcher:ISearchProvider = _plugins[counter] as ISearchProvider;
			searcher.addEventListener(Event.COMPLETE, onSearchComplete);
			searcher.addEventListener(ErrorEvent.ERROR, onSearchError);
			searcher.search(query, durMs);
		}
		
		/**
		 * Executes search with next searcher 
		 */
		private function findNext():void{
			counter++;
			if( counter >= _plugins.length ){ 
				trace('done');
				endLoad();
				return;
			}
			var searcher:ISearchProvider = _plugins[counter] as ISearchProvider;
			//searcher.registerResultEvent(onSearchComplete);
			searcher.addEventListener(Event.COMPLETE, onSearchComplete);
			searcher.search(query);
		}
		
		/**
		 * On search results 
		 * @param e
		 * 
		 */
		private function onSearchComplete(e:Event):void{
			trace('found data!');
			
			var searcher:ISearchProvider = e.target as ISearchProvider;
			searcher.removeEventListener(Event.COMPLETE, onSearchComplete);
			
			if(searcher.result == null || searcher.result.length < 1){
				findNext();
			}else{
				_results = searcher.result.concat(_results);
				findNext();
			}
		}
		
		private function onSearchError(e:ErrorEvent):void{
			trace('error');
			findNext();
		}
		
		// ---------------------------------------------
		public function listPlugins():Array{
			var searcher:ISearchProvider;
			var i:int;
			var res:Array = [];
			for(i = 0; i < _plugins.length; i++){
				searcher = _plugins[i] as ISearchProvider;
				res.push({index: i+1, name: searcher.PLUGIN_NAME, author: searcher.AUTHOR_NAME});
			}
			
			return res;
		}
	}
}