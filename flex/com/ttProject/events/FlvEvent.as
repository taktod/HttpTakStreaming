/**
 * Flex swc library for Http Tak Streaming.
 * 
 * Copyright 2012 - 2012 by Taktod. All rights reserved.
 */
package com.ttProject.events
{
	import flash.events.Event;

	/**
	 * event for FlvEvent
	 */
	public class FlvEvent extends Event
	{
		public static const FLV_EVENT:String = "flvEvent";
		public var info:Object;
		public function FlvEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false, info:Object=null)
		{
			this.info = info;
			super(type, bubbles, cancelable);
		}
	}
}