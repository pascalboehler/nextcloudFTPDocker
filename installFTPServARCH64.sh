# Update the system using apt (ubuntu server)

sudo pacman -Syu --noconfirm

sudo pacman -S git vim --noconfirm

# Check if the drive exists

DRIVE=/dev/sdc 
PARTITION=/dev/sdc1
MOUNTPOINT=/media/hdd
FTPDOMAIN=ftp.example.com
CLOUDDOMAIN=cloud.example.com

if findfs "$DRIVE"; then
	echo "$DRIVE IS VALID"

	# some fdisk magic
	(
		echo n
		echo p
		echo ""
		echo ""
		echo ""
		echo y
		echo w
	) | sudo fdisk "$DRIVE"
	sync
	# create file system on partition
	sudo mkfs.ext4 "$PARTITION"

	# create mount point and mount partition
	sudo mkdir "$MOUNTPOINT"
	sudo mount "$PARTITION" "$MOUNTPOINT"
else
	echo "$DRIVE not found, discarding"
fi

# Install docker via its script and nginx via apt

sudo pacman -S docker --noconfirm

sudo usermod -aG docker $USER

# Install nginx

sudo pacman -S nginx --noconfirm

# install certbot

sudo pacman -S certbot python3-certbot-nginx --noconfirm

# create the nginx files for our domains:

## for the ftp domain (redirect it to a docker container)

(
	echo -e "server {"
	echo -e "\n\tserver_name $FTPDOMAIN;"
	echo -e "\n\tlocation / {"
	echo -e "\t\tproxy_pass http://localhost:6000;"
	echo -e "\t}"
	echo -e "}"
) >> "$FTPDOMAIN"

## for the cloud domain (redirect traffic to the nextcloud container)

(
    echo -e "server {"
    echo -e "\n\tserver_name $CLOUDDOMAIN;"
    echo -e "\n\tlocation / {"
    echo -e "\t\tproxy_pass http://localhost:8008;"
    echo -e "\t}"
    echo -e "}"
) >> "$CLOUDDOMAIN"

## copy the config to its appropriate posititions & create links

sudo mv "./$FTPDOMAIN" "/etc/nginx/sites-available/$FTPDOMAIN"

sudo mv "./$CLOUDDOMAIN" "/etc/nginx/sites-available/$CLOUDDOMAIN"

sudo ln -s "/etc/nginx/sites-available/$FTPDOMAIN" "/etc/nginx/sites-enabled/$FTPDOMAIN"
sudo ln -s "/etc/nginx/sites-available/$CLOUDDOMAIN" "/etc/nginx/sites-enabled/$CLOUDDOMAIN"

## remove that default config:

sudo rm "/etc/nginx/sites-available/default"
sudo rm "/etc/nginx/sites-enabled/default"

# check nginx config and apply it

sudo nginx -t
sudo nginx -s reload

# order the let's encrypt certificates
sudo certbot --nginx -d "$FTPDOMAIN" -d "$CLOUDDOMAIN"

# setup the docker hdd

sudo mkdir /media/hdd/nextcloud_data
sudo mkdir /media/hdd/ftpsite_data

sudo chmod +rwx -R /media/hdd/nextcloud_data
sudo chmod +rwx -R /media/hdd/ftpsite_data

# download the prepared github docker compose file

git clone https://github.com/pascalboehler/nextcloudFTPDocker

# boot up the docker infrastructure

cd nextcloudFTPDocker

# some .env magic

(
	echo -e "DBNAME=nextcloud"
	echo -e "DBUSER=nextcloud"
	echo -e "DBPW="
	echo -e "DBROOTPW="
	echo -e "DOMAIN=$CLOUDDOMAIN"
	echo -e "URL=https://$CLOUDDOMAIN"
) >> ./.env

sudo docker compose up -d


