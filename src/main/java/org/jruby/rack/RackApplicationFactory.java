/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

/**
 * Factory for creating and initializing Rack applications.
 * 
 * @see RackApplication
 * @author nicksieger
 */
public interface RackApplicationFactory {
    
    String RACK_CONTEXT = "rack.context";
    String FACTORY = "rack.factory";

    /** 
     * Initialize the factory (using the given context).
     *
     * @param rackContext the context
     */
    void init(RackContext rackContext) throws RackInitializationException;
    
    /** 
     * Create a new, uninitialized application. The resulting object must be 
     * initialized by calling its {@link RackApplication#init} method.
     *
     * @return a new application
     */
    RackApplication newApplication() throws RackException;
    
    /** 
     * Retrieve an application that is ready to use, possibly creating one 
     * if it's necessary.
     *
     * @return the application
     */
    RackApplication getApplication() throws RackException;
    
    /** 
     * Return the application to the factory after processing. 
     * e.g. for allowing the application to be pooled and/or cleaned up.
     * @param app the application
     */
    void finishedWithApplication(RackApplication app);
    
    /** 
     * Get the designated error application. 
     * The error application is expected to be a singleton and should not be 
     * returned to the factory.
     *
     * @return the error application
     */
    RackApplication getErrorApplication(); // TODO return ErrorApplication
    
    /** 
     * Destroy the factory.
     * Releasing any resources (applications instances) it holds.
     */
    void destroy();
    
    /**
     * Decorates an existing {@link RackApplicationFactory} instance.
     * 
     * @author kares
     */
    public static interface Decorator {
        
        /**
         * @return the delegate factory this decorator wraps
         */
        RackApplicationFactory getDelegate();
        
    }
    
}
