/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.CompatVersion;

/**
 * Centralized interface for configuration options used by JRuby-Rack. JRuby-Rack can either be configured by setting the key-value pairs as init parameters in the servlet context or as VM-wide system properties.
 */
public interface RackConfig {
    /** Return the Ruby version that JRuby should run. */
    CompatVersion getCompatVersion();

    /** Return the rackup Ruby script to be used to launch the application. */
    String getRackup();

    /** Return the path to the Rackup script to be used to launch the application. */
    String getRackupPath();

    /** Return the configured amount of time before runtime acquisition times out (in seconds). */
    Integer getRuntimeTimeoutSeconds();

    /** Get the number of initial runtimes, or null if unspecified. */
    Integer getInitialRuntimes();

    /** Get the number of maximum runtimes, or null if unspecified. */
    Integer getMaximumRuntimes();

    /** Return (optional) command line arguments to be used to configure runtimes. */
    String[] getRuntimeArguments();
    
    /** Get the number of initializer threads, or null if unspecified. */
    Integer getNumInitializerThreads();

    /** Create a logger based on the configuration. */
    RackLogger getLogger();

    /** Return true if passing through the filter should append '.html' or 'index.html' to the path. */
    boolean isFilterAddsHtml();

    /** Return true if the filter should verify the resource exists with
     * ServletContext#getResource before adding .html on the request. */
    boolean isFilterVerifiesResource();

    /** Return the JNDI name of the JMS connection factory.*/
    String getJmsConnectionFactory();

    /** Return the JNDI properties for */
    String getJmsJndiProperties();

    /** Return the threshold/size of the in-memory buffer used for request bodies. */
    //int getMemoryBufferSize();

    /** Return true if the runtimes should be initialized in serial (e.g, if threads cannot be created). */
    boolean isSerialInitialization();

    /** Return true if the request body is rewindable. */
    boolean isRewindable();

    /** Returns true if the outer environment (variables) should not be used. */
    boolean isIgnoreEnvironment();

    /** General property retrieval for custom configuration values. */
    String getProperty(String key);

    /** General property retrieval for custom configuration values. */
    String getProperty(String key, String defaultValue);
}
