/**
 * Flex swc library for logger.
 * 
 * Copyright 2012 - 2012 by Taktod. All rights reserved.
 */
package com.ttProject.logger
{
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.utils.Timer;
	
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.rpc.http.HTTPService;

	/**
	 * make logger and reply
	 */
	public class LoggerFactory
	{
		public static var logdata:Array = new Array();
		private static var loggers:Object = new Object();
		/** setting for all */
		public static var level:int;
		public static var systemName:String;
		public static var timer:Timer;
		private static var targetUrl:String;
		public static function setup(systemName:String="flex", level:int=Logger.WARN, targetUrl:String=null):void {
			// make timer and report them to logadmin for taktod project...
			LoggerFactory.systemName = systemName;
			LoggerFactory.level = level;
			LoggerFactory.targetUrl = targetUrl;
			if(targetUrl != null) {
				timer = new Timer(300000); // send log data each 5min.
				timer.addEventListener(TimerEvent.TIMER, registerData);
				timer.start();
			}
		}
		public static function getLogger(name:String): Logger {
			if(loggers[name] == null) {
				loggers[name] = new Logger(name);
			}
			return loggers[name];
		}
		private static function registerData(event:TimerEvent):void {
			var service:HTTPService;
			service = new HTTPService();
			service.url = targetUrl;
			service.method = "POST";
			service.send({task: "registerLog", data: logdata.join("\n")});
			logdata = new Array();
		}
	}
}