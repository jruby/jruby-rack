/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.CompatVersion;

import java.io.PrintStream;
import java.util.Map;

/**
 * Centralized interface for configuration options used by JRuby-Rack. 
 * 
 * JRuby-Rack can either be configured by setting the key-value pairs as init 
 * parameters (or filter init parameters in case a servlet filter is configured)
 * in the servlet context or as VM-wide system properties.
 */
public interface RackConfig {
    
    /** 
     * The standard output stream to use in the application.
     * @return <code>STDOUT</code>
     */
    PrintStream getOut();

    /** 
     * The standard error stream to use in the application.
     * @return <code>STDERR</code>
     */
    PrintStream getErr();
    
    /** 
     * Return the Ruby version that JRuby should run.
     * @return <code>RUBY_VERSION</code> (e.g. 1.8, 1.9)
     */
    CompatVersion getCompatVersion();

    /** 
     * Return the rackup Ruby script to be used to launch the application.
     *
     * @return the config.ru script
     */
    String getRackup();

    /** 
     * Return the path to the Rackup script to be used to launch the application.
     *
     * @see #getRackup()
     * @return the rackup script path
     */
    String getRackupPath();

    /** 
     * Get the number of initial runtimes to be started, or null if unspecified.
     *
     * @return the initial number of runtimes or null
     */
    Integer getInitialRuntimes();

    /** 
     * Get the number of maximum runtimes to be booted, or null if unspecified.
     *
     * @return the maximum number of runtimes or null
     */
    Integer getMaximumRuntimes();

    /** 
     * Returns (optional) command line arguments to be used when starting Ruby runtimes.
     *
     * @return <code>ARGV</code>
     */
    String[] getRuntimeArguments();

    /**
     * Allows to customize the environment runtimes will be running with.
     * By returning null the environment (JRuby sets up System.getenv) will be
     * kept as is. 
     *
     * @apiNote This method if not returning null should return a mutable map.
     * @return the <code>ENV</code> to be used in started Ruby runtimes
     */
    Map<String, String> getRuntimeEnvironment();
    
    /** 
     * Returns true if the outer environment (variables) should not be used.
     *
     * @return whether to <code>ENV.clear</code> the Ruby runtime
     * @deprecated replaced with {@link #getRuntimeEnvironment()}
     */
    @Deprecated
    boolean isIgnoreEnvironment();
    
    /**
     * Return the configured amount of time before runtime acquisition times out (in seconds).
     *
     * @return the amount of time before runtimes acquisition times out
     */
    @Deprecated // TODO rename to Float getRuntimeAquireTimeout
    Integer getRuntimeTimeoutSeconds();
    
    /**
     * Get the number of initializer threads, or null if unspecified.
     *
     * @return the number of initializer threads or null
     */
    @Deprecated // TODO rename to Integer getRuntimeInitThreads
    Integer getNumInitializerThreads();

    /** 
     * Return true if runtimes should be initialized in serial 
     * (e.g. if the JVM environment does not allow creating threads).
     * By default if multiple application runtimes are used that they're booted
     * in multiple threads to utilize CPU cores for a faster startup time.
     *
     * @return true of runtimes should be initialized in serial
     */
    boolean isSerialInitialization();
    
    /** 
     * Whether the request body will be rewindable (<code>env[rack.input].rewind</code>).
     * Disabling this might improve performance and memory usage a bit.
     *
     * @return true if the request body is rewindable
     */
    boolean isRewindable();
    
    /** 
     * Returns the initial size of the in-memory buffer used for request bodies.
     *
     * @see #isRewindable()
     * @return the initial size of the in-memory buffer
     */
    Integer getInitialMemoryBufferSize();

    /** 
     * Returns the maximum size of the in-memory buffer used for request bodies.
     *
     * @see #isRewindable()
     * @return the maximum size of the in-memory buffer
     */
    Integer getMaximumMemoryBufferSize();
    
    /**
     * @return whether we allow the initialization exception to bubble up
     */
    //boolean isThrowInitException();
    
    /** 
     * Create a logger to be used (based on this configuration).
     * @return a logger instance
     */
    RackLogger getLogger();
    
    /** 
     * Return true if passing through the filter should append '.html' 
     * (or 'index.html') to the path.
     *
     * @return true if the filter should append .html
     * @deprecated configure filter with a nested init-param
     * @see RackFilter
     */
    @Deprecated
    boolean isFilterAddsHtml();

    /** 
     * Return true if filter should verify the resource exists using 
     * ServletContext#getResource before adding .html on the request. 
     *
     * @return true if the filter should verify the resource
     * @deprecated configure filter with a nested init-param
     * @see RackFilter
     */
    @Deprecated
    boolean isFilterVerifiesResource();

    /** 
     * Return the JNDI name of the JMS connection factory.
     *
     * @return the JMS connection factory
     * @deprecated JMS is rarely used thus should not be here
     */
    @Deprecated
    String getJmsConnectionFactory();

    /** 
     * Return the JNDI properties for JMS.
     *
     * @return  the JNDI properties
     * @deprecated JMS is rarely used thus should not be here
     */
    @Deprecated
    String getJmsJndiProperties();
    
    /** 
     * General property retrieval for custom configuration values.
     *
     * @param key the key
     * @return the value of the property as a String
     */
    String getProperty(String key);

    /** 
     * General property retrieval for custom configuration values.
     *
     * @param key the key
     * @param defaultValue the default value
     * @return the value of the property as a String or the default value
     */
    String getProperty(String key, String defaultValue);

    /** 
     * General property retrieval for custom configuration values.
     *
     * @param key the key
     * @return the value of the property as a Number
     */
    Boolean getBooleanProperty(String key);

    /** 
     * General property retrieval for custom configuration values.
     *
     * @param key the key
     * @param defaultValue the default value
     * @return the value of the property as a Boolean or the default value
     */
    Boolean getBooleanProperty(String key, Boolean defaultValue);

    /** 
     * General property retrieval for custom configuration values.
     *
     * @param key the key
     * @return the value of the property as a Number
     */
    Number getNumberProperty(String key);

    /** 
     * General property retrieval for custom configuration values.
     *
     * @param key the key
     * @param defaultValue the default value
     * @return the value of the property as a Number or the default value
     */
    Number getNumberProperty(String key, Number defaultValue);
    
}
