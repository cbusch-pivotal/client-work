#!/bin/bash

# set -eu

pivnet_api_token="$1"
product_slug="$2"
product_version="$3"
product_file_glob="$4"

if [ -z "$pivnet_api_token" ] || [ -z "$product_slug" ] || [ -z "$product_version" ] || [ -z "$product_file_glob" ]; then
    echo -e "ERROR: Improper parameters \n"
    echo -e "\nUSAGE: generate-product-config.sh <PIVNET TOKEN> <PRODUCT SLUG> <PRODUCT VERSION> <FILE GLOB>\n"
    exit 1
fi

tempdir="${product_slug}"
if [ -d "${tempdir}" ]; then
    echo "ERROR: Temporary directory '${tempdir}' already exists. Please delete or rename..."
    exit 1
fi

echo "INFO: Creating temporary directory '${tempdir}'..."
mkdir "${tempdir}"
if [ ! -d "${tempdir}" ]; then
    echo "ERROR: Unable to create temporary directory '${tempdir}'..."
    exit 1
fi

echo "INFO: Generating ${product_slug} configuration template into the '${tempdir}' directory..."
om config-template \
   --pivnet-api-token "${pivnet_api_token}" \
   --pivnet-product-slug "${product_slug}" \
   --product-version "${product_version}" \
   --product-file-glob "${product_file_glob}" \
   --output-directory "${tempdir}"
if [ $? -ne 0 ]; then
    echo "ERROR: 'om config-template' call failed..."
    exit 1
fi

cd "${tempdir}" || exit
proddir="$(ls)/$(ls $(ls))"

# copy the product template to the proper product name
echo "INFO: Copying the ${proddir}/product.yml file to ${product_slug}.yml file..."
cp "${proddir}"/product.yml ./"${product_slug}".yml

# Merge the following files into "elastic-runtime-vars.yml"
varsfile="vars-tmp.yml"
if [ -f "${varsfile}" ]; then rm "${varsfile}"; fi

echo "INFO: Merging vars into a ${product_slug}-vars.yml file..."

{ echo "# ERRAND VARS"; \
  cat "${proddir}"/errand-vars.yml; \
  echo -e "\n# PRODUCT DEFAULT VARS"; \
  cat "${proddir}"/product-default-vars.yml; \
  echo -e "\n# RESOURCE CONFIG VARS"; \
  cat "${proddir}"/resource-vars.yml; } \
  >> "${varsfile}"

# generate and compare the placeholders in the product template to the vars file. This provides the secrets necessary for credhub.
cat "${varsfile}" | grep -Ev "^#|^ " | cut -d: -f1 | sort | uniq > product-vars.lst
cat "${product_slug}".yml | awk -F'[(())]' '/\(\(/ {print $3}' | sort | uniq > product-template-vars.lst

# create a product secrets yml then concatentating the original products vars onto it,
# and finally overwriting the original product vars with the one containing secrets.
diff --suppress-common-lines product-vars.lst product-template-vars.lst | grep "^>" | sed 's/^> //g' > secrets.yml
{ echo "# SECRET VARS"; \
  cat secrets.yml; \
  echo ""; \
  cat "${varsfile}"; } \
  >> "${product_slug}"-vars.yml

# remove temporary files
rm "${varsfile}" secrets.yml product-*.lst

# message to wrap up
echo -e "\n\nTODO: Copy the ${product_slug}-vars.yml to the 'platform-automation-pipelines/foundations/<foundation>/vars' directory"
echo    "IMPORTANT: Edit the 'SECRET VARS' section at the top to add the CREDHUB credential placeholders for runtime resolution."
echo -e "\nTODO: Copy the ${product_slug}.yml to the 'platform-automation-pipelines/foundations/<foundation>/product' directory"

