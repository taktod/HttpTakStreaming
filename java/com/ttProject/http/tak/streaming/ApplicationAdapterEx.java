/**
 * Red5 app sample for Http Tak Streaming.
 * 
 * Copyright 2012 - 2012 by Taktod. All rights reserved.
 */
package com.ttProject.http.tak.streaming;

import org.red5.server.adapter.ApplicationAdapter;
import org.red5.server.api.stream.IBroadcastStream;
import org.red5.server.api.stream.IStreamListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ttProject.http.tak.streaming.flvbyte.FlvByteCreator;

/**
 * to make stream data into flv packet and stream those data to flash player via apache.
 * I named this http tak streaming.
 * @author taktod
 */
public class ApplicationAdapterEx extends ApplicationAdapter {
	/** logger */
	private static final Logger logger = LoggerFactory.getLogger(ApplicationAdapterEx.class);
	private String outputPath;
	private String tmpPath;
	private int interval;
	/**
	 * outputPath
	 * @param path
	 */
	public void setOutputPath(String path) {
		logger.info(path);
		outputPath = path;
	}
	/**
	 * interval for each files
	 * @param interval
	 */
	public void setInterval(int interval) {
		logger.info("" + interval);
		this.interval = interval;
	}
	/**
	 * tmpPath for saveing data.
	 * @param path
	 */
	public void setTmpPath(String path) {
		logger.info(path);
		tmpPath = path;
	}
	/**
	 * {@inheritDoc}
	 */
	@Override
	public void streamBroadcastStart(IBroadcastStream stream) {
		new FlvByteCreator(
				stream,
				interval,
				outputPath,
				tmpPath);
		super.streamBroadcastStart(stream);
	}
	/**
	 * {@inheritDoc}
	 */
	@Override
	public void streamBroadcastClose(IBroadcastStream stream) {
		for(IStreamListener listener : stream.getStreamListeners()) {
			if(listener instanceof FlvByteCreator) {
				FlvByteCreator fbcreator = (FlvByteCreator)listener;
				fbcreator.moveLastFile();
			}
		}
		super.streamBroadcastClose(stream);
	}
}
