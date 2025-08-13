/*
 * Copyright 2002-2018 the original author or authors.
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

package org.springframework.mock.web;

import jakarta.servlet.SessionCookieConfig;
import org.springframework.lang.Nullable;

/**
 * Mock implementation of the {@link jakarta.servlet.SessionCookieConfig} interface.
 *
 * @author Juergen Hoeller
 * @since 4.0
 * @see jakarta.servlet.ServletContext#getSessionCookieConfig()
 * @implNote Source copied into jruby-rack from Spring Test 5.3.39 and minimally changed to support Jakarta Servlet API 5, 
 *           while still compiling to Java 8, which is not supported by Spring's support in 6.0+ (targets only Java 17+).
 */
public class MockSessionCookieConfig implements SessionCookieConfig {

	@Nullable
	private String name;

	@Nullable
	private String domain;

	@Nullable
	private String path;

	@Nullable
	private String comment;

	private boolean httpOnly;

	private boolean secure;

	private int maxAge = -1;


	@Override
	public void setName(@Nullable String name) {
		this.name = name;
	}

	@Override
	@Nullable
	public String getName() {
		return this.name;
	}

	@Override
	public void setDomain(@Nullable String domain) {
		this.domain = domain;
	}

	@Override
	@Nullable
	public String getDomain() {
		return this.domain;
	}

	@Override
	public void setPath(@Nullable String path) {
		this.path = path;
	}

	@Override
	@Nullable
	public String getPath() {
		return this.path;
	}

	@Override
	public void setComment(@Nullable String comment) {
		this.comment = comment;
	}

	@Override
	@Nullable
	public String getComment() {
		return this.comment;
	}

	@Override
	public void setHttpOnly(boolean httpOnly) {
		this.httpOnly = httpOnly;
	}

	@Override
	public boolean isHttpOnly() {
		return this.httpOnly;
	}

	@Override
	public void setSecure(boolean secure) {
		this.secure = secure;
	}

	@Override
	public boolean isSecure() {
		return this.secure;
	}

	@Override
	public void setMaxAge(int maxAge) {
		this.maxAge = maxAge;
	}

	@Override
	public int getMaxAge() {
		return this.maxAge;
	}

}
