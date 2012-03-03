/**
 * Red5 app sample for Http Tak Streaming.
 * 
 * Copyright 2012 - 2012 by Taktod. All rights reserved.
 */
package com.ttProject.http.tak.streaming.flvbyte;

import java.io.File;
import java.io.FileOutputStream;
import java.io.FilenameFilter;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.GregorianCalendar;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.mina.core.buffer.IoBuffer;
import org.red5.io.ITag;
import org.red5.io.amf.Output;
import org.red5.io.flv.FLVHeader;
import org.red5.io.flv.impl.Tag;
import org.red5.io.object.Serializer;
import org.red5.io.utils.IOUtils;
import org.red5.server.api.stream.IBroadcastStream;
import org.red5.server.api.stream.IStreamListener;
import org.red5.server.api.stream.IStreamPacket;
import org.red5.server.net.rtmp.event.IRTMPEvent;
import org.red5.server.stream.IStreamData;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * object to make packet files...
 * @author taktod
 */
public class FlvByteCreator implements IStreamListener {
	/** logger */
	private final Logger logger;
	/** the time length of each packet. */
	private final int interval;
	/** path for packet files. */
	private final String path;
	/** tmp store path for packet files */
	private final String tmpPath;
	/** streamname */
	private String name;
	/** tag header length */
	private final static int TAG_HEADER_LENGTH = 11;
	/** flv header tag length */
	private final static int HEADER_LENDTH = 9;
	/** definition of specific codecs */
	private final static int CODEC_AUDIO_AAC = 10; // AAC
	private final static int CODEC_VIDEO_AVC = 7; // H.264
	/** initial data for flv header */
	private byte[] flvHeader;
	/** passed meta data */
	private byte[] metaData;
	/** packets for initial data. */
	private final List<byte[]> initialData;
	/** codec information for this video */
	private volatile int videoCodecId = -1;
	/** codec information for this audio */
	private volatile int audioCodecId = -1;
	/** processed file number */
	private int fileNum = 0;
	/** custom tag type */
	public static final byte TYPE_EOF = 20;
	/** custom tag packet data */
	public static final byte[] EOF_PACKET = {
		20, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 11
	};
	/**
	 * constructor
	 * @param stream
	 * @param interval
	 * @param path
	 */
	public FlvByteCreator(IBroadcastStream stream, int interval, String path, String tmpPath) {
		this.interval = interval;
		this.path = path + stream.getScope().getPath() + "/" + stream.getScope().getName() + "/";
		this.tmpPath = tmpPath + stream.getScope().getPath() + "/" + stream.getScope().getName() + "/";
		this.logger = LoggerFactory.getLogger(FlvByteCreator.class.getName() + ":" + stream.getName());
		this.initialData = new ArrayList<byte[]>();
		this.name = stream.getPublishedName();
		// no stream with "_" or "."
		if(this.name.indexOf("_") != -1 || this.name.indexOf(".") != -1) {
			stream.close();
			return;
		}
		setupDirectory();
		// setup basic information.
		makeFlvHeader();
		makeMetaData();
		// make header information for the first process.
		writeHeaderPacket();
		// start capture the stream data.
		stream.addStreamListener(this);
	}
	/**
	 * setup directory for working
	 */
	private void setupDirectory() {
		// target path for working.
		File f = new File(this.path);
		f.mkdirs();
		final String streamName = this.name;
		// clear old data.
		File[] list = f.listFiles(new FilenameFilter() {
			@Override
			public boolean accept(File dir, String name) {
				return name.indexOf(streamName + "_") != -1 || name.indexOf(streamName + ".fth") != -1;
			}
		});
		for(File fi : list) {
			fi.delete();
		}
		// tmp path for working
		f = new File(this.tmpPath);
		f.mkdirs();
		// clear old data, too.
		list = f.listFiles(new FilenameFilter() {
			@Override
			public boolean accept(File dir, String name) {
				return name.indexOf(streamName + "_") != -1 || name.indexOf(streamName + ".fth") != -1;
			}
		});
		for(File fi : list) {
			fi.delete();
		}
	}
	/**
	 * make header data and save it on memory.
	 */
	private void makeFlvHeader() {
		FLVHeader flvHeader = new FLVHeader();
		flvHeader.setFlagAudio(audioCodecId != -1);
		flvHeader.setFlagVideo(videoCodecId != -1);
		IoBuffer header = IoBuffer.allocate(HEADER_LENDTH + 4);
		flvHeader.write(header);
		if(header.hasArray()) {
			header.flip();
		}
		else {
			byte[] tmp = new byte[HEADER_LENDTH + 4];
			header.get(tmp);
		}
		this.flvHeader = header.array();
		header.clear();
	}
	/**
	 * make metadata. save it on memory too...
	 */
	private void makeMetaData() {
		// 初期化
		final IoBuffer buf = IoBuffer.allocate(192);
		final Output out;
		final ITag tag;
		final int bodySize;
		final byte dataType;
		final int previousTagSize;
		final int totalTagSize;
		
		// setting up the data.
		buf.setAutoExpand(true);
		out = new Output(buf);
		out.writeString("onMetaData");
		Map<Object, Object> params = new HashMap<Object, Object>();
		params.put("server", "ttProject HttpTakStreaming");
		params.put("creationdate", GregorianCalendar.getInstance().getTime().toString());
		if(videoCodecId != -1) {
			params.put("videocodecid", videoCodecId);
		}
		else {
			params.put("novideocodec", 0);
		}
		if(audioCodecId != -1) {
			params.put("audiocodecid", audioCodecId);
		}
		else {
			params.put("noaudiocodec", 0);
		}
		params.put("canSeekToEnd", true);
		out.writeMap(params, new Serializer());
		buf.flip();
		// make up tag data from settled data.
		tag = new Tag(ITag.TYPE_METADATA, 0, buf.limit(), buf, 0);
		dataType = tag.getDataType();
		bodySize = tag.getBodySize();
		previousTagSize = TAG_HEADER_LENGTH + bodySize;
		totalTagSize = TAG_HEADER_LENGTH + bodySize + 4;

		// data for task.
		final IoBuffer tagBuffer = IoBuffer.allocate(totalTagSize);
		byte[] bodyBuf = new byte[bodySize];

		// pick up data from tag.
		tag.getBody().get(bodyBuf);
		// write data on tagBuffer
		tagBuffer.put(dataType); // data type(1byte)
		IOUtils.writeMediumInt(tagBuffer, bodySize); // data size(3byte)
		IOUtils.writeExtendedMediumInt(tagBuffer, 0); // timestamp(force to zero)(4byte)
		IOUtils.writeMediumInt(tagBuffer, 0); // streamid(force to zero)(3byte)
		tagBuffer.put(bodyBuf); // buffer data(any bytes)
		tagBuffer.putInt(previousTagSize); // end of tag, size information(4byte)
		tagBuffer.flip();
		metaData = tagBuffer.array(); // save the tagBuffer into memory.
		tagBuffer.clear();
		buf.clear();
	}
	/**
	 * make up tag data from flv stream data(ITag).
	 * @param tag
	 */
	private void makeTagData(ITag tag) {
		final int bodySize = tag.getBodySize();
		byte[] result = null;
		if(bodySize > 0) {
			// get informations
			final byte dataType = tag.getDataType();
			final int previousTagSize = TAG_HEADER_LENGTH + bodySize;
			final int totalTagSize = TAG_HEADER_LENGTH + bodySize + 4;
			final int timeStamp = tag.getTimestamp();
			int num = tag.getTimestamp() / interval; // make up num for files from timestamp information.
			if(num < fileNum) {
				num = fileNum;
			}
			final byte firstByte;
			final int id;

			// prepare
			IoBuffer tagBuffer = IoBuffer.allocate(totalTagSize);
			byte[] bodyBuf = new byte[bodySize];

			tag.getBody().get(bodyBuf);
			// hold the codec information.
			firstByte = bodyBuf[0];
			tagBuffer.put(dataType); // data type(1byte)
			IOUtils.writeMediumInt(tagBuffer, bodySize); // information data(3byte)
			if(dataType == ITag.TYPE_METADATA) {
				IOUtils.writeExtendedMediumInt(tagBuffer, 0); // timestamp for metadata(force to zero)(4byte)
			}
			else {
				IOUtils.writeExtendedMediumInt(tagBuffer, timeStamp); // timestamp for data(4byte)
			}
			IOUtils.writeMediumInt(tagBuffer, 0); // streamid(force to zero)(3byte)
			tagBuffer.put(bodyBuf); // data(any bytes)
			tagBuffer.putInt(previousTagSize); // final tag length(4byte)
			tagBuffer.flip();
			result = tagBuffer.array();
			tagBuffer.clear();
			// write tag into packet file.
			writePacket(result, num);

			// for meta data first packet of video or audio in specific codec...
			switch(dataType) {
			case ITag.TYPE_AUDIO:
				if(audioCodecId == -1) {
					// recognize the codec
					id = firstByte & 0xFF;
					audioCodecId = (id & ITag.MASK_SOUND_FORMAT) >> 4;
					if(audioCodecId == CODEC_AUDIO_AAC) { // for aac we need to keep first packet for playing the middle of movie.
						initialData.add(result);
					}
					// update header, cause audio information is updated...
					makeFlvHeader();
					makeMetaData();
					writeHeaderPacket();
				}
				break;
			case ITag.TYPE_VIDEO:
				if(videoCodecId == -1) {
					// recognize the codec
					id = firstByte & 0xFF;
					videoCodecId = (id & ITag.MASK_VIDEO_CODEC);
					if(videoCodecId == CODEC_VIDEO_AVC) { // for h.264 we need to keep first packet for playing the middle of movie.
						initialData.add(result);
					}
					// update header, cuz video info is updated.
					makeFlvHeader();
					makeMetaData();
					writeHeaderPacket();
				}
				break;
			case ITag.TYPE_METADATA:
				// update header, cus meta data is updated.
				initialData.add(result);
				writeHeaderPacket();
				break;
			}
		}
	}
	/**
	 * make up custom eof data.
	 */
	private void makeEofData() {
		// write data on packet
		writePacket(EOF_PACKET, fileNum);
	}
	/**
	 * write header packet into file.
	 */
	private void writeHeaderPacket() {
		OutputStream output = null;
		try {
			// write directly to path.
			output = new FileOutputStream(path + name + ".fth");
			// header
			output.write(flvHeader);
			// metadata for initial
			output.write(metaData);
			// intial data(metadata, h.264 or aac first packet)
			for(byte[] initialDat : initialData) {
				output.write(initialDat);
			}
		}
		catch (Exception e) {
			logger.error("writeHeaderPacket", e);
		}
		try {
			if(output != null) {
				output.close();
				output = null;
			}
		}
		catch (Exception e) {
			logger.error("writeHeaderPacket", e);
		}
	}
	/**
	 * write data packet into file
	 */
	private void writePacket(byte[] data, int num) {
		// if we have old data on tmp directory, move it to path.
		if(num != fileNum) {
			rename(num);
			this.fileNum = num;
		}
		// write
		OutputStream output = null;
		try {
			output = new FileOutputStream(tmpPath + name + "_" + num + ".ftm", true);
			output.write(data);
			output.close();
		}
		catch (Exception e) {
			logger.error("writePacket", e);
		}
		try {
			if(output != null) {
				output.close();
				output = null;
			}
		}
		catch (Exception e) {
			logger.error("writePacket", e);
		}
	}
	/**
	 * move files from tmpPath to path
	 * @param num
	 */
	private void rename(int num) {
		try {
			File file = new File(tmpPath + name + "_" + (num - 1) + ".ftm");
			if(file.exists()) {
				// if exists, rename it
				File toFile = new File(path + name + "_" + (num - 1) + ".ftm");
				file.renameTo(toFile);
			}
		}
		catch(Exception e) {
			logger.error("rename", e);
		}
	}
	/**
	 * in the case of stream stop, put the eof on the data. like unpublish message on rtmp.
	 */
	public void moveLastFile() {
		makeEofData();
		rename(fileNum + 1); // to move current file num. update plus one.
	}
	/**
	 * {@inheritDoc}
	 */
	@Override
	public void packetReceived(IBroadcastStream stream, IStreamPacket packet) {
		try {
			// if it's not rtmpEvent, nor streamData... skip.
			if(!(packet instanceof IRTMPEvent) || !(packet instanceof IStreamData)) {
				return;
			}
			IRTMPEvent rtmpEvent = (IRTMPEvent) packet;
			// check the size, if zero, ignore
			if(rtmpEvent.getHeader().getSize() == 0) {
				return;
			}
			// make tag from row data.
			ITag tag = new Tag();
			tag.setDataType(rtmpEvent.getDataType());
			tag.setTimestamp(rtmpEvent.getTimestamp());
			@SuppressWarnings("rawtypes")
			IoBuffer data = ((IStreamData) rtmpEvent).getData().asReadOnlyBuffer();
			tag.setBodySize(data.limit());
			tag.setBody(data);
			makeTagData(tag);
		}
		catch(Exception e) {
			logger.error("packetReceived", e);
		}
	}
}
