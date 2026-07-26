/* StakeDXF native converter — LibreDWG DWG → DXF for on-device use. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>

#include <dwg.h>

/* Must match LibreDWG src/bits.h Bit_Chain layout. */
typedef struct _bit_chain
{
  unsigned char *chain;
  size_t size;
  size_t byte;
  unsigned char bit;
  unsigned char opts;
  Dwg_Version_Type version;
  Dwg_Version_Type from_version;
  FILE *fh;
  BITCODE_RS codepage;
} Bit_Chain;

int dwg_write_dxf (Bit_Chain *restrict dat, Dwg_Data *restrict dwg);

#ifdef __cplusplus
extern "C" {
#endif

__attribute__((visibility("default")))
int stakedxf_convert(const char *input_path,
                     const char *output_path,
                     char *err_buf,
                     int err_len)
{
  Dwg_Data dwg;
  Bit_Chain dat;
  int error;

  if (!input_path || !output_path)
  {
    if (err_buf && err_len > 0)
      snprintf(err_buf, (size_t)err_len, "missing path");
    return 1;
  }

  memset(&dwg, 0, sizeof(dwg));
  memset(&dat, 0, sizeof(dat));
  dwg.opts = 1;

  error = dwg_read_file(input_path, &dwg);
  if (error >= DWG_ERR_CRITICAL)
  {
    if (err_buf && err_len > 0)
      snprintf(err_buf, (size_t)err_len, "DWG read failed (0x%x)", error);
    dwg_free(&dwg);
    return 2;
  }

  /* Prefer R2010 for Trimble Access compatibility */
  dwg.header.version = R_2010;
  dat.version = dwg.header.version;
  dat.from_version = dwg.header.from_version;

  dat.fh = fopen(output_path, "wb");
  if (!dat.fh)
  {
    if (err_buf && err_len > 0)
      snprintf(err_buf, (size_t)err_len, "cannot write %s", output_path);
    dwg_free(&dwg);
    return 3;
  }

  error = dwg_write_dxf(&dat, &dwg);
  fclose(dat.fh);
  dwg_free(&dwg);

  if (error >= DWG_ERR_CRITICAL)
  {
    if (err_buf && err_len > 0)
      snprintf(err_buf, (size_t)err_len, "DXF write failed (0x%x)", error);
    return 4;
  }

  if (err_buf && err_len > 0)
    err_buf[0] = '\0';
  return 0;
}

__attribute__((visibility("default")))
const char *stakedxf_version(void)
{
  return "1.0.0-native";
}

#ifdef __cplusplus
}
#endif
