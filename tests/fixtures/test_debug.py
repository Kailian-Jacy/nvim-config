"""Python test fixture for DAP debugging tests."""
import time


def factorial(n):
    """Compute factorial recursively."""
    if n <= 1:
        return 1
    result = n * factorial(n - 1)
    return result


def greet(name):
    """Greet someone."""
    message = f"Hello, {name}!"
    return message


def main():
    x = 10
    y = factorial(5)
    z = x + y
    greeting = greet("World")
    print(f"Result: {z}")
    print(greeting)
    time.sleep(0.1)
    print("Done")


if __name__ == "__main__":
    main()
