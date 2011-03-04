/**
 * DUI: The Digg User Interface Library
 *
 * Copyright (c) 2008-2009, 2011, Digg, Inc.
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
 * @module DUI
 * @author Micah Snyder <micah@digg.com>
 * @description The Digg User Interface Library
 * @version 0.0.5
 * @link http://code.google.com/p/digg
 *
 */
// NJS: Copied from https://github.com/digg/stream/raw/master/js/DUI.js
/* Add Array.prototype.indexOf -- Guess which major browser doesn't support it natively yet? */
[].indexOf || (Array.prototype.indexOf = function(v, n){
    n = (n == null) ? 0 : n; var m = this.length;

    for(var i = n; i < m; i++) {
        if(this[i] == v) return i;
    }

    return -1;
});

(function($) {

/* Create our top-level namespace */
DUI = {};

/**
 * @class Class Class creation and management for use with jQuery. Class is a singleton that handles static and dynamic classes, as well as namespaces
 */
DUI.Class = {
    /**
     * @var {Array} _dontEnum Internal array of keys to omit when looking through a class' properties. Once the real DontEnum bit is writable we won't have to deal with this.
     */
    _dontEnum: ['_ident', '_dontEnum', 'create', 'namespace', 'ns', 'supers', 'sup', 'init', 'each'],

    /**
     * @function create Make a class! Do work son, do work
     * @param {optional Object} methods Any number of objects can be passed in as arguments to be added to the class upon creation
     * @param {optional Boolean} static If the last argument is Boolean, it will be treated as the static flag. Defaults to false (dynamic)
     */
    create: function() {
        //Set _this to DUI.Class
        var _this = this;

        //Figure out if we're creating a static or dynamic class
        var s = (arguments.length > 0 && //if we have arguments...
                arguments[arguments.length - 1].constructor == Boolean) ? //...and the last one is Boolean...
                    arguments[arguments.length - 1] : //...then it's the static flag...
                    false; //...otherwise default to a dynamic class

        //Static: Object, dynamic: Function
        var c = s ? {} : function() {
            this.init.apply(this, arguments);
        }

        //All of our classes have these in common
        var methods = {
            _ident: {
                library: "DUI.Class",
                version: "0.0.5",
                dynamic: true
            },

            //_dontEnum should exist in our classes as well
            _dontEnum: this._dontEnum,

            //A basic namespace container to pass objects through
            ns: [],

            //A container to hold one level of overwritten methods
            supers: {},

            //A constructor
            init: function() {},

            //Our namespace function
            namespace:function(ns) {
                //Don't add nothing
                if (!ns) return null;

                //Set _this to the current class, not the DUI.Class lib itself
                var _this = this;

                //Handle ['ns1', 'ns2'... 'nsN'] format
                if(ns.constructor == Array) {
                    //Call namespace normally for each array item...
                    $.each(ns, function() {
                        _this.namespace.apply(_this, [this]);
                    });

                    //...then get out of this call to namespace
                    return;

                //Handle {'ns': contents} format
                } else if(ns.constructor == Object) {
                    //Loop through the object passed to namespace
                    for(var key in ns) {
                        //Only operate on Objects and Functions
                        if([Object, Function].indexOf(ns[key].constructor) > -1) {
                            //In case this.ns has been deleted
                            if(!this.ns) this.ns = [];

                            //Copy the namespace into an array holder
                            this.ns[key] = ns[key];

                            //Apply namespace, this will be caught by the ['ns1', 'ns2'... 'nsN'] format above
                            this.namespace.apply(this, [key]);
                        }
                    }

                    //We're done with namespace for now
                    return;
                }

                //Note: [{'ns': contents}, {'ns2': contents2}... {'nsN': contentsN}] is inherently handled by the above two cases

                var levels = ns.split(".");

                /* Dynamic classes are Functions, so we'll extend their prototype.
                   Static classes are Objects, so we'll extend them directly */
                var nsobj = this.prototype ? this.prototype : this;

                $.each(levels, function() {
                    /* When adding a namespace check to see, in order:
                     * 1) Does the ns exist in our ns passthrough object?
                     * 2) Does the ns already exist in our class
                     * 3) Does the ns exist as a global var?
                     *    NOTE: Support for this was added so that you can namespace classes
                     *    into other classes, i.e. MyContainer.namespace('MyUtilClass'). this
                     *    behaviour is dangerously greedy though, so it may be removed.
                     * 4) If none of the above, make a new static class
                     */
                    nsobj[this] = _this.ns[this] || nsobj[this] || window[this] || DUI.Class.create(true);

                    /* If our parent and child are both dynamic classes, copy the child out of Parent.prototype and into Parent.
                     * It seems weird at first, but this allows you to instantiate a dynamic sub-class without instantiating
                     * its parent, e.g. var baz = new Foo.Bar();
                     */
                    if(_this.prototype && DUI.isClass(nsobj[this]) && nsobj[this].prototype) {
                        _this[this] = nsobj[this];
                    }

                    //Remove our temp passthrough if it exists
                    delete _this.ns[this];

                    //Move one level deeper for the next iteration
                     nsobj = nsobj[this];
                });

                //TODO: Do we really need to return this? It's not that useful anymore
                return nsobj;
            },

            /* Create exists inside classes too. neat huh?
             * Usage differs slightly: MyClass.create('MySubClass', { myMethod: function() }); */
            create: function() {
                //Turn arguments into a regular Array
                var args = Array.prototype.slice.call(arguments);

                //Pull the name of the new class out
                var name = args.shift();

                //Create a new class with the rest of the arguments
                var temp = DUI.Class.create.apply(DUI.Class, args);

                //Load our new class into the {name: class} format to pass it into namespace()
                var ns = {};
                ns[name] = temp;

                //Put the new class into the current one
                this.namespace(ns);
            },

            //Iterate over a class' members, omitting built-ins
            each: function(cb) {
                if(!$.isFunction(cb)) {
                    throw new Error('DUI.Class.each must be called with a function as its first argument.');
                }

                //Set _this to the current class, not the DUI.Class lib itself
                var _this = this;

                $.each(this, function(key) {
                    if(_this._dontEnum.indexOf(key) != -1) return;

                    cb.apply(this, [key, this]);
                });
            },

            //Call the super of a method
            sup: function() {
                try {
                    var caller = this.sup.caller.name;
                    this.supers[caller].apply(this, arguments);
                } catch(noSuper) {
                    return false;
                }
            }
        }

        //Static classes don't need a constructor
        s ? delete methods.init : null;

        //...nor should they be identified as dynamic classes
        s ? methods._ident.dynamic = false : null;

        /* Put default methods into the class before anything else,
         *   so that they'll be overwritten by the user-specified ones */
        $.extend(c, methods);

        /* Second copy of methods for dynamic classes: They get our
         * common utils in their class definition AND their prototype */
        if(!s) $.extend(c.prototype, methods);

        //Static: extend the Object, Dynamic: extend the prototype
        var extendee = s ? c : c.prototype;

        //Loop through arguments. If they're the right type, tack them on
        $.each(arguments, function() {
            //Either we're passing in an object full of methods, or the prototype of an existing class
            if(this.constructor == Object || typeof this.init != undefined) {
                /* Here we're going per-property instead of doing $.extend(extendee, this) so that
                 * we overwrite each property instead of the whole namespace. Also: we omit the 'namespace'
                 * helper method that DUI.Class tacks on, as there's no point in storing it as a super */
                for(i in this) {
                    /* If a property is a function (other than our built-in helpers) and it already exists
                     * in the class, save it as a super. note that this only saves the last occurrence */
                    if($.isFunction(extendee[i]) && _this._dontEnum.indexOf(i) == -1) {
                        //since Function.name is almost never set for us, do it manually
                        this[i].name = extendee[i].name = i;

                        //throw the existing function into this.supers before it's overwritten
                        extendee.supers[i] = extendee[i];
                    }

                    //Special case! If 'dontEnum' is passed in as an array, add its contents to DUI.Class._dontEnum
                    if(i == 'dontEnum' && this[i].constructor == Array) {
                        extendee._dontEnum = $.merge(extendee._dontEnum, this[i]);
                    }

                    //extend the current property into our class
                    extendee[i] = this[i];
                }
            }
        });

        //Shiny new class, ready to go
        return c;
    }
};

/* Turn DUI into a static class whose contents are DUI.
   Now you can use DUI's tools on DUI itself, i.e. DUI.create('Foo');
   I'm pretty sure this won't melt the known universe, but caveat emptor. */
DUI = DUI.Class.create(DUI, true);

})(jQuery);

//Simple check so see if the object passed in is a DUI Class
DUI.isClass = function(check, type)
{
    type = type || false;

    try {
        if(check._ident.library == 'DUI.Class') {
            if((type == 'dynamic' && !check._ident.dynamic)
               || (type == 'static' && check._ident.dynamic)) {
                return false;
            }

            return true;
        }
    } catch(noIdentUhOh) {
        return false;
    }

    return false;
}
