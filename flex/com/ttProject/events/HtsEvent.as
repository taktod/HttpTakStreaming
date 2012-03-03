/**
 * Flex swc library for Http Tak Streaming.
 * 
 * Copyright 2012 - 2012 by Taktod. All rights reserved.
 */
package com.ttProject.events
{
	/**
	 * event for HtsStream
	 */
	public class HtsEvent extends FlvEvent
	{
		public static const HTS_EVENT:String = "htsEvent";
		public function HtsEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false, info:Object=null)
		{
			super(type, bubbles, cancelable, info);
		}
	}
}