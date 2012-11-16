/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.CompatVersion;

import java.io.PrintStream;

/**
 * Centralized interface for configuration options used by JRuby-Rack. 
 * 
 * JRuby-Rack can either be configured by setting the key-value pairs as init 
 * parameters (or filter init parameters in case a servlet filter is configured)
 * in the servlet context or as VM-wide system properties.
 */
public interface RackConfig {
    
    /** The standard output stream to use in the application */
    PrintStream getOut();

    /** The standard error stream to use in the application */
    PrintStream getErr();

    /** Create a logger based on the configuration. */
    RackLogger getLogger();
    
    /** Return the Ruby version that JRuby should run. */
    CompatVersion getCompatVersion();

    /** Return the rackup Ruby script to be used to launch the application. */
    String getRackup();

    /** Return the path to the Rackup script to be used to launch the application. */
    String getRackupPath();

    /** Get the number of initial runtimes, or null if unspecified. */
    Integer getInitialRuntimes();

    /** Get the number of maximum runtimes, or null if unspecified. */
    Integer getMaximumRuntimes();

    /** Return (optional) command line arguments to be used to configure runtimes. */
    String[] getRuntimeArguments();

    /** Return the configured amount of time before runtime acquisition times out (in seconds). */
    @Deprecated // TODO rename to Float getRuntimeAquireTimeout
    Integer getRuntimeTimeoutSeconds();
    
    /** Get the number of initializer threads, or null if unspecified. */
    @Deprecated // TODO rename to Integer getRuntimeInitThreads
    Integer getNumInitializerThreads();

    /** Return true if the runtimes should be initialized in serial (e.g. if threads cannot be created). */
    boolean isSerialInitialization();

    /** Returns true if the outer environment (variables) should not be used. */
    boolean isIgnoreEnvironment();

    /** Return true if the request body is rewindable. */
    boolean isRewindable();
    
    /** Return the initial size of the in-memory buffer used for request bodies. */
    Integer getInitialMemoryBufferSize();

    /** Return the maximum size of the in-memory buffer used for request bodies. */
    Integer getMaximumMemoryBufferSize();
    
    /**
     * @return whether we allow the initialization exception to bubble up
     */
    //boolean isThrowInitException();
    
    /** 
     * Return true if passing through the filter should append '.html' 
     * (or 'index.html') to the path.
     * 
     * @deprecated configure filter with a nested init-param
     * @see RackFilter
     */
    @Deprecated
    boolean isFilterAddsHtml();

    /** 
     * Return true if filter should verify the resource exists using 
     * ServletContext#getResource before adding .html on the request. 
     * 
     * @deprecated configure filter with a nested init-param
     * @see RackFilter
     */
    @Deprecated
    boolean isFilterVerifiesResource();

    /** Return the JNDI name of the JMS connection factory.*/
    String getJmsConnectionFactory();

    /** Return the JNDI properties for JMS. */
    String getJmsJndiProperties();
    
    /** General property retrieval for custom configuration values. */
    String getProperty(String key);

    /** General property retrieval for custom configuration values. */
    String getProperty(String key, String defaultValue);

    /** General property retrieval for custom configuration values. */
    Boolean getBooleanProperty(String key);

    /** General property retrieval for custom configuration values. */
    Boolean getBooleanProperty(String key, Boolean defaultValue);

    /** General property retrieval for custom configuration values. */
    Number getNumberProperty(String key);

    /** General property retrieval for custom configuration values. */
    Number getNumberProperty(String key, Number defaultValue);
    
}
