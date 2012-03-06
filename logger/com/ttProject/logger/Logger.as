/**
 * Flex swc library for logger.
 * 
 * Copyright 2012 - 2012 by Taktod. All rights reserved.
 */
package com.ttProject.logger
{
	import flash.external.ExternalInterface;
	import flash.utils.getQualifiedClassName;
	
	import mx.formatters.DateFormatter;
	import mx.utils.ObjectUtil;

	public class Logger
	{
		/** output level */
		public static const FATAL:int = 0;
		public static const ERROR:int = 1;
		public static const WARN:int  = 2;
		public static const INFO:int  = 3;
		public static const DEBUG:int = 4;
		public static const TRACE:int = 5;
		private var name:String;
		public function Logger(name:String) {
			this.name = name;
		}
		public function fatal(data:*):void {
			if(LoggerFactory.level >= FATAL) {
				write(data, "FATAL");
			}
		}
		public function error(data:*):void {
			if(LoggerFactory.level >= ERROR) {
				write(data, "ERROR");
			}
		}
		public function warn(data:*):void {
			if(LoggerFactory.level >= WARN) {
				write(data, "WARN");
			}
		}
		public function info(data:*):void {
			if(LoggerFactory.level >= INFO) {
				write(data, "INFO");
			}
		}
		public function debug(data:*):void {
			if(LoggerFactory.level >= DEBUG) {
				write(data, "DEBUG");
			}
		}
		public function trace(data:*):void {
			if(LoggerFactory.level >= TRACE) {
				write(data, "TRACE");
			}
		}
		private function write(data:*, level:String):void {
			// date
			var formatter:DateFormatter = new DateFormatter();
			formatter.formatString = "YYYY-MM-DD JJ:NN:SS";
			var line:String = formatter.format(new Date()) + ",";
			// level
			line += level + ",";
			// LOGName
			line += LoggerFactory.systemName + ",";
			// file and position(this is for debug player only, so ignore now...)
			line += name + ",,";
/*			try {
				throw new Error();
			}
			catch(e:Error) {
			}*/
			if(data is String) {
				line += message(data);
			}
			else if(data is Error) {
				line += exception(data);
			}
			else {
				line += dump(data, "	");
			}
			LoggerFactory.logdata.push(line);
//			ExternalInterface.call("console.log", line);
		}
		private function dump(data:Object, tab:String):String {
			var result:Array = new Array();
			result.push(getQualifiedClassName(data));
			var line:String = "";
			return ObjectUtil.toString(data);
		}
		private function message(data:String):String {
			return data;
		}
		private function exception(data:Error):String {
			return data.toString();
		}
	}
}