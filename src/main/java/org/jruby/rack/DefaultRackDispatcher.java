/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;

import org.jruby.rack.servlet.ServletRackContext;

/**
 * Dispatcher suited for use in a servlet container
 * @author nick
 *
 */
public class DefaultRackDispatcher extends AbstractRackDispatcher {

    private Integer errorApplicationFailureStatusCode = 500;

    public DefaultRackDispatcher(RackContext context) {
        super(context);
    }

    public Integer getErrorApplicationFailureStatusCode() {
        return errorApplicationFailureStatusCode;
    }

    public void setErrorApplicationFailureStatusCode(Integer code) {
        this.errorApplicationFailureStatusCode = code;
    }

    @Override
    protected RackApplication getApplication() throws RackException {
        return getRackFactory().getApplication();
    }

    @Override
    protected void afterException(
            final RackEnvironment request,
            final Exception e,
            final RackResponseEnvironment response)
        throws IOException, RackException {

        RackApplication errorHandler = new ErrorApplicationHandler(getErrorApplication(), e);
        try {
            errorHandler.call(request).respond(response);
        }
        catch (final RuntimeException re) {
            // allow the error app to re-throw Ruby/JRuby-Rack exceptions :
            if (re instanceof RackException) throw (RackException) re;
            //if (e instanceof RaiseException) throw (RaiseException) e;
            // TODO seems redundant maybe we should let the container decide ?!
            context.log(RackLogger.ERROR, "error app failed to handle exception: " + e, re);
            Integer errorCode = getErrorApplicationFailureStatusCode();
            if ( errorCode != null && errorCode.intValue() > 0 ) {
                response.sendError(errorCode);
            }
            else {
                throw re;
            }
        }
    }

    @Override
    protected void afterProcess(RackApplication app) {
        getRackFactory().finishedWithApplication(app);
    }

    @Override
    public void destroy() {
        getRackFactory().destroy();
    }

    protected RackApplicationFactory getRackFactory() {
        if (context instanceof ServletRackContext) {
            return ((ServletRackContext) context).getRackFactory();
        }
        throw new IllegalStateException("not a servlet rack context");
    }

    private RackApplication getErrorApplication() {
        return getRackFactory().getErrorApplication();
    }

}
