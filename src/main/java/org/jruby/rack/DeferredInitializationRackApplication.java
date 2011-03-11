package org.jruby.rack;

import org.jruby.Ruby;

import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 *
 */
public class DeferredInitializationRackApplication implements RackApplication {

    private RackApplication inner;
    private ExecutorService executorService;
    private Future<RackApplication> future;
    private AtomicBoolean done = new AtomicBoolean(false);

    public DeferredInitializationRackApplication(RackApplication inner) {
        this.inner = inner;
        executorService = Executors.newSingleThreadExecutor();
    }

    public RackResponse call(RackEnvironment env) {
        return maybeBlockForInit().call(env);
    }

    public void init() throws RackInitializationException {
        future = executorService.submit(new Callable<RackApplication>() {
            public RackApplication call() throws Exception {
                inner.init();
                return inner;
            }
        });
    }

    public void destroy() {
        maybeBlockForInit().destroy();
    }

    public Ruby getRuntime() {
        return maybeBlockForInit().getRuntime();
    }

    private RackApplication maybeBlockForInit() {
        if (future == null) {
            throw new IllegalStateException("Rack application is not expecting to service calls before the init() method is called.");
        }
        if (done.get()) {
            return inner;
        } else {
            try {
                future.get();
            } catch (ExecutionException ee) {
                throw new RuntimeException (ee);
            } catch (InterruptedException ie) {
                throw new RuntimeException(ie);
            }
            executorService.shutdownNow();
            return inner;
        }
    }
}
