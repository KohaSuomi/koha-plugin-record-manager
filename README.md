
# Koha-Suomi plugin RecordManager

The Record Manager plugin provides tools for managing bibliographic records in Koha, with a focus on detecting and managing orphaned component parts that reference non-existent host records.

## Features

- **Orphan Record Detection**: Identify component parts (MARC leader position 7 = 'a' or 'b') that reference host records via MARC field 773$w, where the referenced host is not found from database with linking values.
- **REST API**: Provides endpoints to query orphan records programmatically
- **Test Data Management**: Includes scripts to populate test data and clean up test records

# Downloading

From the release page you can download the latest \*.kpz file

# Installing

Koha's Plugin System allows for you to add additional tools and reports to Koha that are specific to your library. Plugins are installed by uploading KPZ ( Koha Plugin Zip ) packages. A KPZ file is just a zip file containing the perl files, template files, and any other files necessary to make the plugin work.

The plugin system needs to be turned on by a system administrator.

To set up the Koha plugin system you must first make some changes to your install.

    Change <enable_plugins>0<enable_plugins> to <enable_plugins>1</enable_plugins> in your koha-conf.xml file
    Confirm that the path to <pluginsdir> exists, is correct, and is writable by the web server
    Remember to allow access to plugin directory from Apache

    <Directory <pluginsdir>>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    Restart your webserver

Once set up is complete you will need to alter your UseKohaPlugins system preference. On the Tools page you will see the Tools Plugins and on the Reports page you will see the Reports Plugins.

# Configuring

Here is the place for configurations

## API Endpoints

The plugin provides REST API endpoints for managing records:

### GET /api/v1/contrib/kohasuomi/records/orphans

Returns a list of orphan component parts - records that reference non-existent host records.

**Response**: JSON array of orphan records with details about the missing host references.

## Testing

The plugin includes test scripts to help you test the orphan detection functionality.

### Populate Test Data

Create test records (host records, component parts, and orphans) for testing:

```bash
cd Koha/Plugin/Fi/KohaSuomi/RecordManager/t/
perl populate_test_data.pl --verbose
```

**Options:**
- `--hosts=N` - Number of host records to create (default: 10)
- `--components=N` - Number of component parts per host (default: 3)
- `--orphans=N` - Number of orphan component parts (default: 5)
- `--verbose` - Print detailed output
- `--help` - Show help message

**Examples:**
```bash
# Use defaults (10 hosts, 3 components each, 5 orphans)
perl populate_test_data.pl

# Create more test data
perl populate_test_data.pl --hosts=20 --components=5 --orphans=10 --verbose
```

**Test Data Structure:**
- **Host records**: Control numbers 100001-100999 in field 001
- **Component parts**: Control numbers 200001-299999 in field 001, linked to existing hosts via 773$w
- **Orphan records**: Control numbers 800001-899999 in field 001, referencing non-existent hosts (999001+) in 773$w

### Clear Test Data

Remove all test records (and any invalid records with corrupted MARC data):

```bash
cd Koha/Plugin/Fi/KohaSuomi/RecordManager/t/
perl clear_test_data.pl --verbose
```

**Options:**
- `--delete` - Deletes the records
- `--verbose` - Print detailed output
- `--help` - Show help message

**Examples:**
```bash
# Preview what will be deleted
perl clear_test_data.pl --verbose

# Actually delete the records
perl clear_test_data.pl --delete --verbose
```

The clearing script will:
1. Identify all test records by their control number ranges (100xxx, 200xxx, 800xxx)
2. Identify any records with invalid/corrupted MARC data
3. Delete all identified records
4. Report success/failure for each deletion

## Development

### Record Structure

**Host Records**:
- MARC leader position 7: 's' (serial) or 'm' (monograph)
- Field 001: Control number (e.g., `100001`)
- Field 003: Control number identifier (e.g., `FI-MELINDA`)

**Component Parts**:
- MARC leader position 7: 'a' (monographic component part) or 'b' (serial component part)
- Field 001: Control number for the component part
- Field 003: Control number identifier
- Field 773: Host item entry
  - Subfield $w: Control number of host record (e.g., `(FI-MELINDA)100001`)
  - Subfield $t: Title of host record

**Orphan Component Parts**:
- Same structure as component parts, but 773$w references a host control number that doesn't exist in the database
