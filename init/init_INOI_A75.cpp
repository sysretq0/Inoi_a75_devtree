#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <android-base/properties.h>

#define _REALLY_INCLUDE_SYS__SYSTEM_PROPERTIES_H_
#include <sys/_system_properties.h>

using android::base::GetProperty;
using std::string;

void property_override(string prop, string value)
{
    auto pi = (prop_info *)__system_property_find(prop.c_str());

    if (pi != nullptr)
        __system_property_update(pi, value.c_str(), value.size());
    else
        __system_property_add(prop.c_str(), prop.size(), value.c_str(), value.size());
}

void vendor_load_properties()
{
    string prop_partitions[] = {"", "vendor.", "odm."};
    for (const string &prop : prop_partitions)
    {
        property_override(string("ro.product.") + prop + string("brand"), "INOI");
        property_override(string("ro.product.") + prop + string("manufacturer"), "INOI_Limited");
        property_override(string("ro.product.") + prop + string("name"), "INOI_A75_Elegance");
        property_override(string("ro.product.") + prop + string("device"), "INOI_A75_Elegance");
        property_override(string("ro.product.") + prop + string("model"), "A750");
        property_override(string("ro.product.") + prop + string("marketname"), "INOI A75 Elegance");
        property_override(string("ro.product.system.") + prop + string("device"), "INOI_A75_Elegance");
    }

    property_override("ro.build.display.id", "INOI_A750_ID_U_V7_20260822_user");
    property_override("ro.build.description", "INOI_A750_ID_U_V7_20260822_user");
    property_override("ro.build.version.incremental", "60821");
    property_override("ro.build.fingerprint", "INOI/INOI_A75_Elegance/INOI_A75_Elegance:14/UP1A.231005.007/60821:user/release-keys");
}
