FROM ubuntu:18.04

# easy to use dockerfile for ready-to-go sugar compilation:
# compile with:
#   docker build . -t sugar-portable
# run in any directory with:
#   docker run -it -v (pwd):/root/work sugar-portable sh -c "~/src/perl/repo/Sugar/CLI/ProjectCompiler.pm --watch_directory work/src/ work/Assets/"
# comes packed with all of the dependencies necessary for all of sugar lib

RUN apt update && apt install -y cpanminus make gcc unzip
RUN cpanm Term::ANSIColor Carp IO::Dir Archive::Zip File::Hotfolder

copy ./Sugar /root/src/perl/repo/Sugar
ENV PERL5LIB=/root/src/perl/repo

WORKDIR /root
CMD ["bash"]
