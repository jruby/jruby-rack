/*
 * Copyright 2002-2022 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.springframework.web.util;

import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletRequestWrapper;
import org.springframework.lang.Nullable;

/**
 * Miscellaneous utilities for web applications.
 * Used by various framework classes.
 *
 * @author Rod Johnson
 * @author Juergen Hoeller
 * @author Sebastien Deleuze
 * @implNote Source copied into jruby-rack from Spring Test 5.3.39 and minimally changed to support Jakarta Servlet API 5,
 *           while still compiling to Java 8, which is not supported by Spring's support in 6.0+ (targets only Java 17+).
 */
public abstract class WebUtils {

	/**
	 * Default character encoding to use when {@code request.getCharacterEncoding}
	 * returns {@code null}, according to the Servlet spec.
	 * @see ServletRequest#getCharacterEncoding
	 */
	public static final String DEFAULT_CHARACTER_ENCODING = "ISO-8859-1";

	/**
	 * Standard Servlet spec context attribute that specifies a temporary
	 * directory for the current web application, of type {@code java.io.File}.
	 */
	public static final String TEMP_DIR_CONTEXT_ATTRIBUTE = "jakarta.servlet.context.tempdir";

	/**
	 * Return an appropriate request object of the specified type, if available,
	 * unwrapping the given request as far as necessary.
	 * @param request the servlet request to introspect
	 * @param requiredType the desired type of request object
	 * @return the matching request object, or {@code null} if none
	 * of that type is available
	 */
	@SuppressWarnings("unchecked")
	@Nullable
	public static <T> T getNativeRequest(ServletRequest request, @Nullable Class<T> requiredType) {
		if (requiredType != null) {
			if (requiredType.isInstance(request)) {
				return (T) request;
			}
			else if (request instanceof ServletRequestWrapper) {
				return getNativeRequest(((ServletRequestWrapper) request).getRequest(), requiredType);
			}
		}
		return null;
	}
}
