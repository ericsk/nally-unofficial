# Mengjuei Hsieh, University of California Irvine

all:
	xcodebuild

clean:
	xcodebuild clean;	\
	rm -fr build;		\
	rm -f Nally.xcodeproj/${USER}.*

install: all
	rm -r /Applications/Nally.app; mv build/Release/Nally.app /Applications/

test: all
	xcodebuild test -project Nally.xcodeproj -scheme TextSuiteTests

release: all
	python Scripts/package.py build/Release/Nally.app http://nally.googlecode.com/files
