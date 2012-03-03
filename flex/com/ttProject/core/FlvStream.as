/**
 * Flex swc library for Http Tak Streaming.
 * 
 * Copyright 2012 - 2012 by Taktod. All rights reserved.
 */
package com.ttProject.core
{
	import com.ttProject.events.FlvEvent;
	import com.ttProject.logger.Logger;
	import com.ttProject.logger.LoggerFactory;
	
	import flash.events.EventDispatcher;
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
	import flash.media.SoundTransform;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.NetStreamAppendBytesAction;
	import flash.utils.ByteArray;
	import flash.utils.Timer;

	/**
	 * working with netStream.appendByte
	 */
	public class FlvStream extends EventDispatcher
	{
		/** logger */
		private static var logger:Logger = LoggerFactory.getLogger("FlvStream");
		/** true means ready to receive flv bytes */
		private var initializeFlg:Boolean;
		private var nc:NetConnection;
		private var ns:NetStream;
		private var startPosition:uint;
		
		/** - properties ---------------------------------------- */
		private var _client:Object;
		private var _soundTransForm:SoundTransform;
		private var _bufferTime:Number;
		public function get bufferLength():Number {
			if(ns != null) {
				return ns.bufferLength;
			}
			return -1;
		}
		public function get bufferTime():Number {
			if(ns != null) {
				return ns.bufferTime;
			}
			return _bufferTime;
		}
		public function set bufferTime(value:Number):void {
			if(ns != null) {
				ns.bufferTime = value;
			}
			else {
				_bufferTime = value;
			}
		}
		public function get byteLoaded():uint {
			if(ns != null) {
				return ns.bytesLoaded;
			}
			return 0;
		}
		public function get bytesTotal():uint {
			if(ns != null) {
				return ns.bytesTotal;
			}
			return 0;
		}
		public function set client(value:Object):void {
			if(ns != null) {
				ns.client = value;
			}
			else {
				_client = value;
			}
		}
		public function get client():Object {
			if(ns != null) {
				return ns.client;
			}
			return _client;
		}
		public function get currentFPS():Number {
			if(ns != null) {
				return ns.currentFPS;
			}
			return -1;
		}
		public function set soundTransform(value:SoundTransform):void {
			if(ns != null) {
				ns.soundTransform = value;
			}
			else {
				_soundTransForm = value;
			}
		}
		public function get soundTransform():SoundTransform {
			if(ns != null) {
				return ns.soundTransform;
			}
			return _soundTransForm;
		}
		public function get time():Number {
			if(ns != null) {
				return ns.time;
			}
			return -1;
		}
		[Deprecated]
		public function get _ns():NetStream {
			return ns;
		}
		/** - methods ------------------------------------------- */
		/**
		 * constructor
		 */
		public function FlvStream()
		{
			initializeFlg = false;
			ns = null;
			startPosition = 0;
			_client = null;
			_soundTransForm = null;
			_bufferTime = -1;
			nc = new NetConnection();
			nc.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			nc.connect(null);
		}
		/**
		 * close event
		 */
		public function close():void {
			dispatchEvent(new FlvEvent(FlvEvent.FLV_EVENT, false, false, {code:"FlvEvent.Close"}));
			ns.close();
			ns = null;
		}
		private function onNetStatus(event:NetStatusEvent):void
		{
			dispatchEvent(new NetStatusEvent(event.type, event.bubbles, event.cancelable, event.info));
			if(event.info.code == "NetConnection.Connect.Success") {
				dispatchEvent(new FlvEvent(FlvEvent.FLV_EVENT, false, false, {code:"FlvEvent.Initialize"}));
				initializeFlg = true;
			}
		}
		protected function setup():Boolean {
			if(!initializeFlg) {
				return false;
			}
			if(ns != null) {
				ns.close();
			}
			ns = new NetStream(nc);
			ns.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			ns.bufferTime = 0;
			if(_client != null) {
				ns.client = _client;
				_client = null;
			}
			if(_soundTransForm != null) {
				ns.soundTransform = _soundTransForm;
				_soundTransForm = null;
			}
			if(_bufferTime != -1) {
				ns.bufferTime = _bufferTime;
				_bufferTime = -1;
			}
			ns.play(null);
			dispatchEvent(new FlvEvent(FlvEvent.FLV_EVENT, false, false, {code:"FlvEvent.Start"}));
			return true;
		}
		protected function appendHeaderBytes(data:ByteArray):void {
			if(initializeFlg && ns != null) {
				ns.appendBytesAction(NetStreamAppendBytesAction.RESET_BEGIN);
				ns.appendBytes(data);
				ns.appendBytesAction(NetStreamAppendBytesAction.END_SEQUENCE);
			}
		}
		protected function appendBytes(rawdata:ByteArray):void {
			if(initializeFlg && ns != null) {
				var data:ByteArray = timestampInjection(rawdata);
				if(data != null) {
					ns.appendBytes(data);
				}
			}
		}
		private function timestampInjection(data:ByteArray):ByteArray {
			var ba:ByteArray = new ByteArray;
			ba.writeBytes(data);
			try {
				ba.position = 0;
				var dataType:int = ba.readByte();
				if(startPosition == 0) {
					switch(dataType) {
						case 8: // audio
							return null;
						case 18: // meta
							ba.position = 0;
							return ba;
						case 9: // video
							ba.position = 11;
							if(ba.readByte() & 0x10 == 0x00) {
								return null;
							}
							break;
						default:
							return null;
					}
				}
				ba.position = 4;
				var timestamp:uint = ((ba.readByte() + 0x0100) & 0xFF) * 0x010000
					+ ((ba.readByte() + 0x0100) & 0xFF) * 0x0100
					+ ((ba.readByte() + 0x0100) & 0xFF) * 0x01
					+ ((ba.readByte() + 0x0100) & 0xFF) * 0x01000000;
				var newTimestamp:uint = 0;
				switch(dataType) {
					case 8: // audio
						newTimestamp = timestamp - startPosition;
						break;
					case 9: // video
						if(startPosition == 0) {
							startPosition = timestamp;
						}
						newTimestamp = timestamp - startPosition;
						break;
					case 18: // meta
						newTimestamp = timestamp - startPosition;
						break;
					case 20: // eof
						dispatchEvent(new FlvEvent(FlvEvent.FLV_EVENT, false, false, {code:"FlvEvent.Unpublish"}));
						return null;
					default: // unknown
						return null;
				}
				ba.position = 4;
				ba.writeByte((newTimestamp / 0x010000) & 0xFF);
				ba.writeByte((newTimestamp / 0x0100) & 0xFF);
				ba.writeByte((newTimestamp / 0x01) & 0xFF);
				ba.writeByte((newTimestamp / 0x01000000) & 0xFF);
				ba.position = 0;
			}
			catch(e:Error) {
				;
			}
			return ba;
		}
	}
}