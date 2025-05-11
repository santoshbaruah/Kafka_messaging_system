import time
import logging
import functools
from enum import Enum

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("circuit-breaker")

class CircuitState(Enum):
    CLOSED = "CLOSED"  # Normal operation, requests are allowed
    OPEN = "OPEN"      # Circuit is open, requests are not allowed
    HALF_OPEN = "HALF_OPEN"  # Testing if service is back to normal

class CircuitBreaker:
    """
    Implementation of the Circuit Breaker pattern.

    This pattern prevents an application from repeatedly trying to execute an operation
    that's likely to fail, allowing it to continue without waiting for the fault to be fixed
    or wasting CPU cycles while it's self-recovering.
    """

    def __init__(self, name, failure_threshold=5, reset_timeout=60, half_open_max_calls=3):
        """
        Initialize a new circuit breaker.

        Args:
            name (str): Name of this circuit breaker for identification
            failure_threshold (int): Number of failures before opening the circuit
            reset_timeout (int): Seconds to wait before attempting to close the circuit
            half_open_max_calls (int): Maximum number of calls to allow in half-open state
        """
        self.name = name
        self.failure_threshold = failure_threshold
        self.reset_timeout = reset_timeout
        self.half_open_max_calls = half_open_max_calls

        # State variables
        self.failure_count = 0
        self.last_failure_time = None
        self.state = CircuitState.CLOSED
        self.half_open_calls = 0

        logger.info(f"Circuit breaker '{name}' initialized with failure_threshold={failure_threshold}, "
                   f"reset_timeout={reset_timeout}s, half_open_max_calls={half_open_max_calls}")

    def __call__(self, func):
        """
        Decorator to wrap a function with circuit breaker functionality.

        Args:
            func: The function to wrap

        Returns:
            The wrapped function
        """
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            return self.call(func, *args, **kwargs)
        return wrapper

    def call(self, func, *args, **kwargs):
        """
        Call the protected function respecting the circuit breaker state.

        Args:
            func: The function to call
            *args: Arguments to pass to the function
            **kwargs: Keyword arguments to pass to the function

        Returns:
            The result of the function call

        Raises:
            CircuitBreakerError: If the circuit is open
        """
        # Check if circuit is open
        if self.state == CircuitState.OPEN:
            if self._should_attempt_reset():
                logger.info(f"Circuit '{self.name}' transitioning from OPEN to HALF_OPEN")
                self.state = CircuitState.HALF_OPEN
                self.half_open_calls = 0
            else:
                raise CircuitBreakerError(f"Circuit '{self.name}' is OPEN")

        # Check if we've exceeded half-open call limit
        if self.state == CircuitState.HALF_OPEN and self.half_open_calls >= self.half_open_max_calls:
            raise CircuitBreakerError(f"Circuit '{self.name}' is HALF_OPEN and has exceeded max calls")

        # Increment half-open call counter
        if self.state == CircuitState.HALF_OPEN:
            self.half_open_calls += 1

        try:
            # Call the function
            result = func(*args, **kwargs)

            # Success - reset failure count and close circuit if in half-open state
            self._on_success()

            return result

        except Exception as e:
            # Failure - increment failure count and potentially open circuit
            self._on_failure()

            # Re-raise the original exception
            raise

    def _on_success(self):
        """Handle a successful call."""
        if self.state == CircuitState.HALF_OPEN:
            logger.info(f"Circuit '{self.name}' transitioning from HALF_OPEN to CLOSED")
            self.state = CircuitState.CLOSED

        # Reset failure count
        self.failure_count = 0

    def _on_failure(self):
        """Handle a failed call."""
        self.failure_count += 1
        self.last_failure_time = time.time()

        logger.warning(f"Circuit '{self.name}' recorded failure {self.failure_count}/{self.failure_threshold}")

        # If we've reached the threshold, open the circuit
        if self.state == CircuitState.CLOSED and self.failure_count >= self.failure_threshold:
            logger.warning(f"Circuit '{self.name}' transitioning from CLOSED to OPEN")
            self.state = CircuitState.OPEN

        # If we're in half-open state and have a failure, go back to open
        if self.state == CircuitState.HALF_OPEN:
            logger.warning(f"Circuit '{self.name}' transitioning from HALF_OPEN to OPEN")
            self.state = CircuitState.OPEN

    def _should_attempt_reset(self):
        """Check if enough time has passed to attempt resetting the circuit."""
        if self.last_failure_time is None:
            return True

        elapsed = time.time() - self.last_failure_time
        return elapsed >= self.reset_timeout

    def reset(self):
        """Manually reset the circuit breaker to closed state."""
        logger.info(f"Circuit '{self.name}' manually reset to CLOSED")
        self.failure_count = 0
        self.state = CircuitState.CLOSED
        self.half_open_calls = 0

    def force_open(self):
        """Manually force the circuit breaker to open state."""
        logger.warning(f"Circuit '{self.name}' manually forced to OPEN")
        self.state = CircuitState.OPEN
        self.last_failure_time = time.time()

class CircuitBreakerError(Exception):
    """Exception raised when a circuit breaker prevents an operation."""
    pass
