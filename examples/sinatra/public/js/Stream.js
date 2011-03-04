/**
 * DUI.Stream: A JavaScript MXHR client
 *
 * Copyright (c) 2009, 2011, Digg, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 * - Neither the name of the Digg, Inc. nor the names of its contributors
 *   may be used to endorse or promote products derived from this software
 *   without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 * @module DUI.Stream
 * @author Micah Snyder <micah@digg.com>
 * @author Jordan Alperin <alpjor@digg.com>
 * @description A JavaScript MXHR client
 * @version 0.0.3
 * @link http://github.com/digg/dui
 *
 */
// NJS: Copied from https://github.com/digg/stream/raw/master/js/Stream.js
(function($) {
DUI.create('Stream', {
    pong: null,
    lastLength: 0,
    streams: [],
    listeners: {},

    init: function() {

    },

    load: function(url) {
        //These versions of XHR are known to work with MXHR
        try { this.req = new ActiveXObject('MSXML2.XMLHTTP.6.0'); } catch(nope) {
            try { this.req = new ActiveXObject('MSXML3.XMLHTTP'); } catch(nuhuh) {
                try { this.req = new XMLHttpRequest(); } catch(noway) {
                    throw new Error('Could not find supported version of XMLHttpRequest.');
                }
            }
        }

        //These versions don't support readyState == 3 header requests
        //try { this.req = new ActiveXObject('Microsoft.XMLHTTP'); } catch(err) {}
        //try { this.req = new ActiveXObject('MSXML2.XMLHTTP.3.0'); } catch(err) {}

        this.req.open('GET', url, true);

        var _this = this;
        this.req.onreadystatechange = function() {
            _this.readyStateNanny.apply(_this);
        }

        this.req.send(null);
    },

    readyStateNanny: function() {
        if(this.req.readyState == 3 && this.pong == null) {
            var contentTypeHeader = this.req.getResponseHeader("Content-Type");

            if(contentTypeHeader.indexOf("multipart/mixed") == -1) {
                this.req.onreadystatechange = function() {
                    throw new Error('Send it as multipart/mixed, genius.');
                    this.req.onreadystatechange = function() {};
                }.bind(this);

            } else {
                this.boundary = '--' + contentTypeHeader.split('"')[1];

                //Start pinging
                this.pong = window.setInterval(this.ping.bind(this), 15);
            }
        }

        if(this.req.readyState == 4) {
            //var contentTypeHeader = this.req.getResponseHeader("Content-Type");

            //Stop the insanity!
            clearInterval(this.pong);

            //One last ping to clean up
            this.ping();

            if(typeof this.listeners.complete != 'undefined') {
                var _this = this;
                $.each(this.listeners.complete, function() {
                    this.apply(_this);
                });
            }
        }
    },

    ping: function() {
        var length = this.req.responseText.length;

        var packet = this.req.responseText.substring(this.lastLength, length);

        this.processPacket(packet);

        this.lastLength = length;
    },

    processPacket: function(packet) {
        if(packet.length < 1) return;

        //I don't know if we can count on this, but it's fast as hell
        var startFlag = packet.indexOf(this.boundary);

        var endFlag = -1;

        //Is there a startFlag?
        if(startFlag > -1) {
            if(typeof this.currentStream != 'undefined') {
            //If there's an open stream, that's an endFlag, not a startFlag
                endFlag = startFlag;
                startFlag = -1;
            } else {
            //No open stream? Ok, valid startFlag. Let's try find an endFlag then.
                endFlag = packet.indexOf(this.boundary, startFlag + this.boundary.length);
            }
        }

        //No stream is open
        if(typeof this.currentStream == 'undefined') {
            //Open a stream
            this.currentStream = '';

            //Is there a start flag?
            if(startFlag > -1) {
            //Yes
                //Is there an end flag?
                if(endFlag > -1) {
                //Yes
                    //Use the end flag to grab the entire payload in one swoop
                    var payload = packet.substring(startFlag, endFlag);
                    this.currentStream += payload;

                    //Remove the payload from this chunk
                    packet = packet.replace(payload, '');

                    this.closeCurrentStream();

                    //Start over on the remainder of this packet
                    this.processPacket(packet);
                } else {
                //No
                    //Grab from the start of the start flag to the end of the chunk
                    this.currentStream += packet.substr(startFlag);

                    //Leave this.currentStream set and wait for another packet
                }
            } else {
                //WTF? No open stream and no start flag means someone ****** up the output
                //...OR maybe they're sending garbage in front of their first payload. Weird.
                //I guess just ignore it for now?
            }
        //Else we have an open stream
        } else {
            //Is there an end flag?
            if(endFlag > -1) {
            //Yes
                //Use the end flag to grab the rest of the payload
                var chunk = packet.substring(0, endFlag);
                this.currentStream += chunk;

                //Remove the rest of the payload from this chunk
                packet = packet.replace(chunk, '');

                this.closeCurrentStream();

                //Start over on the remainder of this packet
                this.processPacket(packet);
            } else {
            //No
                //Put this whole packet into this.currentStream
                this.currentStream += packet;

                //Wait for another packet...
            }
        }
    },

    closeCurrentStream: function() {
        //Write stream. Not sure if we need this
        //this.streams.push(this.currentStream);

        //Get mimetype
        //First, ditch the boundary
        this.currentStream = this.currentStream.replace(this.boundary + "\n", '');

        /* The mimetype is the first line after the boundary.
           Note that RFC 2046 says that there's either a mimetype here or a blank line to default to text/plain,
           so if the payload starts on the line after the boundary, we'll intentionally ditch that line
           because it doesn't conform to the spec. QQ more noob, L2play, etc. */
        var mimeAndPayload = this.currentStream.split("\n");

        var mime = mimeAndPayload.shift().split('Content-Type:', 2)[1].split(";", 1)[0].replace(' ', '');

        //Better to have this null than undefined
        mime = mime ? mime : null;

        //Get payload
        var payload = mimeAndPayload.join("\n");

        //Try to fire the listeners for this mimetype
        var _this = this;
        if(typeof this.listeners[mime] != 'undefined') {
            $.each(this.listeners[mime], function() {
                this.apply(_this, [payload]);
            });
        }

        //Set this.currentStream = null
        delete this.currentStream;
    },

    listen: function(mime, callback) {
        if(typeof this.listeners[mime] == 'undefined') {
            this.listeners[mime] = [];
        }

        if(typeof callback != 'undefined' && callback.constructor == Function) {
            this.listeners[mime].push(callback);
        }
    }
});
})(jQuery);

//Yep, I still use this. So what? You wanna fight about it?
Function.prototype.bind = function() {
    var __method = this, object = arguments[0], args = [];

    for(i = 1; i < arguments.length; i++)
        args.push(arguments[i]);

    return function() {
        return __method.apply(object, args);
    }
}

/* GLOSSARY
    packet: the amount of data sent in one ping interval
    payload: an entire piece of content, contained between multipart boundaries
    stream: the data sent between opening and closing an XHR. depending on how you implement MHXR, that could be a while.
*/
