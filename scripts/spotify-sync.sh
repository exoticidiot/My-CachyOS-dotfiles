#!/bin/bash
pacman -S --noconfirm spotify
chown -R the_exotic_idiot:the_exotic_idiot /opt/spotify
spicetify backup apply
