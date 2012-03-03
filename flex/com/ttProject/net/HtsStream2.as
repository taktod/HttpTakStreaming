/**
 * Flex swc library for Http Tak Streaming.
 * 
 * Copyright 2012 - 2012 by Taktod. All rights reserved.
 */
package com.ttProject.net
{
	import com.ttProject.core.FlvStream;
	import com.ttProject.events.HtsEvent;
	import com.ttProject.logger.Logger;
	import com.ttProject.logger.LoggerFactory;
	
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.media.Sound;
	import flash.media.SoundTransform;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.NetStreamAppendBytesAction;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Timer;

	/**
	 * stream Object to handle http tak streaming.
	 * 
	 * ftfファイルは何度もダウンロードするように変更。
	 * fthファイルのIDが前とかわった場合は、ストリームが変更になっているので、再度アクセスし直す必要がある。
	 * アクセスした場合に、0だった場合はageが進んでいないので、interval分まつ・・・みたいなことにしておく。
	 * なお、読み込んでから余裕がある場合はなるべく遅延するようにした方がいいと思う。
	 * より正確に動作させるために、unixミリ秒をつかった方がよさげ。Date.getTime()で取得できます。
	 */
	public class HtsStream2 extends FlvStream
	{
		/** logger object */
		private static var logger:Logger = LoggerFactory.getLogger("HtsStream");
		private var fthFile:String;
		private var ftfFile:String;
		private var ftmArray:Array;
		/** length of each packet */
		private var packetInterval:int;
		private var timer:Timer;
		/** true means now loading some file. */
		private var loadingFlg:Boolean;
		/**
		 * constructor
		 */
		public function HtsStream2()
		{
			// initialize all
			fthFile = null;
			ftfFile = null;
			ftmArray = new Array();
			packetInterval = -1;
			timer = null;
			loadingFlg = false;
			super();
		}
		/**
		 * start to play
		 */
		public function play(htsUrl:String):void
		{
			this.ftfFile = htsUrl;
			// download xml dataa from ftfFile url
			downloadXml(ftfFile, onFileLoad);
		}
		/**
		 * close the stream
		 */
		override public function close():void
		{
			// stop timer
			timer.stop();
			super.close();
		}

		private function onFileLoad(data:XML):void {
			// xml tags...
			var base:String = "httpTakStreaming".toLowerCase();
			var interval:String = "packetInterval".toLowerCase();
			var header:String = "flvTakHeader".toLowerCase();
			var media:String = "flvTakMedia".toLowerCase();
			// check the base tag
			if(data.name().localName.toLowerCase() != base) {
				return;
			}
			for each (var element:XML in data.elements()) {
				var name:String = element.name().localName.toLowerCase();
				if(name == interval) {
					try {
						packetInterval = parseInt(element.text());
					}
					catch(e:Error) {
						logger.error(e);
					}
				}
				else if(name == header && fthFile == null) {
					fthFile = element.text();
				}
				else if(name == media) {
					if(element.text().indexOf("*") != -1) {
						// sequence data
						ftmArray.push({"data": element.text(), "start": element.@start});
					}
					else {
						// solid data
						ftmArray.push(element.text());
					}
				}
			}
			// イベントその１ftfファイル取得完了
			dispatchEvent(new HtsEvent(HtsEvent.HTS_EVENT, false, false, {code:"FtfFile.Download"}));
			logger.info(packetInterval);
			logger.info(fthFile);
			logger.info(ftmArray);
			// set the timer for downloads
			timer = new Timer(packetInterval); // execute download process each 1 sec
			timer.addEventListener(TimerEvent.TIMER, onTimerEvent);
			timer.start();
			// starting http tak streaming.
			// download fthFile at the beginning
			loadingFlg = true;
			downloadData(fthFile, onLoadedFthData);
		}
		private function onLoadedFthData(byteArray:ByteArray):void {
			// get fth data before finish flvStream setting up.
			if(!setup()) {
				// must try after flvStream setting up.
				return;
			}
			appendHeaderBytes(byteArray);
			loadingFlg = false;
			// fthファイル取得完了
			dispatchEvent(new HtsEvent(HtsEvent.HTS_EVENT, false, false, {code:"FthFile.Download"}));
		}
		private function onLoadedData(byteArray:ByteArray):void {
			// at this point shift up the ftm list
			var data:* = ftmArray.shift();
			if(data is Object && data.start != null && data.data != null) {
				// for sequence data, increment target and put the data bask to ftm list.
				data.start ++;
				ftmArray.unshift(data);
			}
			ftmData(byteArray);
			loadingFlg = false;
			// ftmファイル取得完了
			dispatchEvent(new HtsEvent(HtsEvent.HTS_EVENT, false, false, {code:"FtmFile.Download"}));
		}
		private function ftmData(data:ByteArray):void {
			var length:int = data.length;
			var pos:int = 0;
			try {
				while(true) {
					data.position = 1 + pos;
					var size:int = ((data.readByte() + 0x0100) & 0xFF) * 0x010000
						+ ((data.readByte() + 0x0100) & 0xFF) * 0x0100
						+ ((data.readByte() + 0x0100) & 0xFF);
					var chunkSize:int = 11 + size + 4;
					var ba:ByteArray = new ByteArray;
					data.position = pos;
					data.readBytes(ba, 0, chunkSize);
					// ba is the target packet data.
					appendBytes(ba);
					pos += chunkSize;
					if(pos == length) {
						break;
					}
				}
			}
			catch(e:Error) {
				logger.error(e);
			}
		}
		private function onTimerEvent(event:TimerEvent):void {
			if(loadingFlg) {
				// if the other timer event is nor finished... skip
				return;
			}
			// get the targegt ftm file
			var data:* = ftmArray[0];
			if(data is String) {
				loadingFlg = true;
				downloadData(data, onLoadedData);
			}
			else if(data is Object && data.start != null && data.data != null) {
				loadingFlg = true;
				var index:int = data.start;
				var target:String = data.data;
				target = target.replace(/\*/i, index);
				downloadData(target, onLoadedData);
			}
		}
		private function downloadXml(target:String, task:Function):void {
			var loader:URLLoader = new URLLoader();
			loader.addEventListener(Event.COMPLETE, function(event:Event):void {
				try {
					var data:XML = XML(loader.data);
					task(data);
				}
				catch(e:Error) {
					logger.error(e);
				}
			});
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function(event:SecurityErrorEvent):void {
				logger.error("Xml securityError:" + event);
			});
			loader.addEventListener(IOErrorEvent.IO_ERROR, function(event:IOErrorEvent):void {
				logger.error("Xml IOError:" + event);
			});
			var request:URLRequest = new URLRequest(target);
			try {
				loader.load(request);
			}
			catch(e:Error) {
				logger.error(e);
			}
		}
		private function downloadData(target:String, task:Function):void {
			var loader:URLLoader = new URLLoader;
			loader.dataFormat = URLLoaderDataFormat.BINARY;
			loader.addEventListener(Event.COMPLETE, function(event:Event):void {
				task(loader.data as ByteArray);
			});
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function(event:SecurityErrorEvent):void {
				logger.error("Data securityError:" + event);
				loadingFlg = false;
			});
			loader.addEventListener(IOErrorEvent.IO_ERROR, function(event:IOErrorEvent):void {
				logger.error("Data IOError:" + event);
				loadingFlg = false;
			});
			var request:URLRequest = new URLRequest(target);
			try {
				loader.load(request);
			}
			catch(e:Error) {
				logger.error(e);
			}
		}
	}
}