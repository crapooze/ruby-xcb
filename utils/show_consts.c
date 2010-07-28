#include <stdlib.h>
#include <stdio.h>

#include <xcb/xcb.h>

int main(int argc, char ** argv)
{
	printf("XCB_EXPOSE = %d\n", XCB_EXPOSE);
	printf("XCB_NONE = %d\n", XCB_NONE);
	printf("XCB_CURRENT_TIME = %d\n", XCB_CURRENT_TIME);
	printf("XCB_NO_SYMBOL = %d\n", XCB_NO_SYMBOL);
	printf("XCB_COPY_FROM_PARENT: %d\n", XCB_COPY_FROM_PARENT);
	return 0;
}
