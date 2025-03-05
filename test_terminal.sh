#!/bin/bash

# Test script for terminal interaction
echo "This is a test script for terminal interaction"
echo "Please answer the following questions:"

echo -n "Do you like apples? (y/n): "
read answer
if [ "$answer" = "y" ]; then
    echo "Great! Apples are good for you."
else
    echo "That's okay, there are many other fruits to enjoy."
fi

echo -n "Press Enter to continue..."
read

echo "Now let's test a multi-choice selection:"
echo "1) Option One"
echo "2) Option Two"
echo "3) Option Three"
echo -n "Select an option (1-3): "
read option

case $option in
    1)
        echo "You selected Option One"
        ;;
    2)
        echo "You selected Option Two"
        ;;
    3)
        echo "You selected Option Three"
        ;;
    *)
        echo "Invalid option"
        ;;
esac

echo "Test completed successfully!"
