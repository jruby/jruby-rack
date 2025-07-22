/*
 * Copyright 2002-2013 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.jruby.rack.mock;

import org.jruby.rack.RackLogger;

public class RackLoggingMockServletContext extends org.springframework.mock.web.MockServletContext {
    private RackLogger logger = new NullLogger();

    public RackLoggingMockServletContext() {
    }

    public RackLoggingMockServletContext(String resourceBasePath) {
        super(resourceBasePath);
    }

    private static class NullLogger extends RackLogger.Base {

        @Override
        public void log(String message) { /* NOOP */ }

        @Override
        public void log(String message, Throwable ex) { /* NOOP */ }

        @Override
        public boolean isEnabled(Level level) {
            return false;
        }

        @Override
        public void log(Level level, String message) { /* NOOP */ }

        @Override
        public void log(Level level, String message, Throwable ex) { /* NOOP */ }

        @Override
        public Level getLevel() {
            return null;
        }

    }

    @Override
    public void log(String message) {
        logger.log(message);
    }

    @Override
    public void log(String message, Throwable ex) {
        logger.log(message, ex);
    }

    public RackLogger getLogger() {
        return (logger instanceof NullLogger) ? null : logger;
    }

    public void setLogger(RackLogger logger) {
        this.logger = logger == null ? new NullLogger() : logger;
    }
}
