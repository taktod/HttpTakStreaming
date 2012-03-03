/**
 * Flex swc library for Http Tak Streaming.
 * 
 * Copyright 2012 - 2012 by Taktod. All rights reserved.
 */
package com.ttProject.media
{
	import com.ttProject.events.HtsEvent;
	import com.ttProject.logger.Logger;
	import com.ttProject.logger.LoggerFactory;
	import com.ttProject.net.HtsStream;
	import com.ttProject.net.HtsStream2;
	
	import flash.media.Video;
	import flash.net.NetStream;
	
	/**
	 * media.Video for HtsStreaming
	 */
	public class HtsVideo extends Video
	{
		/** logger */
		private static var logger:Logger = LoggerFactory.getLogger("HtsVideo");
		/**
		 * constructor
		 */
		public function HtsVideo(width:int=320, height:int=240)
		{
			super(width, height);
		}
		/**
		 * attach support for htsStream.
		 */
		public function attachHtsStream(htsStream:*):void {
			logger.info("try to attach HtsStream");
			var ns:NetStream = htsStream._ns;
			if(ns == null) {
				logger.info("ns is null");
				var video:HtsVideo = this;
				htsStream.addEventListener(HtsEvent.HTS_EVENT, function(event:HtsEvent):void {
					if(event.info.code == "FthFile.Download") {
						logger.info("attach here...");
						video.attachNetStream(htsStream._ns);
					}
				});
			}
			else {
				logger.info("ns is not null");
				attachNetStream(ns);
			}
		}
	}
}